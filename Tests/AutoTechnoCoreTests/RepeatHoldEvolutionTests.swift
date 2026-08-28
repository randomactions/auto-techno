import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Bounded repeat hold evolution", .serialized)
struct RepeatHoldEvolutionTests {
    @Test("Core rotates only qualified families after two repeats")
    func boundaryPolicyIsBounded() {
        let allFamilies = RepeatHoldEvolutionPatternFamily.allCases
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 1,
            successorPrepared: false,
            qualifiedPatternFamilies: allFamilies
        ) == .exactAcceptedPCM)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 2,
            successorPrepared: false,
            qualifiedPatternFamilies: allFamilies
        ) == .qualifiedPattern(.deepBreath))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 3,
            successorPrepared: false,
            qualifiedPatternFamilies: allFamilies
        ) == .qualifiedPattern(.twinPulse))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 4,
            successorPrepared: false,
            qualifiedPatternFamilies: allFamilies
        ) == .qualifiedPattern(.lateVeil))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 5,
            successorPrepared: false,
            qualifiedPatternFamilies: allFamilies
        ) == .qualifiedPattern(.deepBreath))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 3,
            successorPrepared: false,
            qualifiedPatternFamilies: [.deepBreath, .lateVeil]
        ) == .qualifiedPattern(.lateVeil))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 9,
            successorPrepared: true,
            qualifiedPatternFamilies: allFamilies
        ) == .exactAcceptedPCM)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 9,
            successorPrepared: false,
            qualifiedPatternFamilies: []
        ) == .exactAcceptedPCM)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 9,
            successorPrepared: false,
            qualifiedPatternFamilies: allFamilies,
            exactAcceptedPCMRequired: true
        ) == .exactAcceptedPCM)
        #expect(!RepeatHoldEvolutionPlaybackMode.qualifiedPattern(.twinPulse)
            .participatesInCanonicalLiveFeedback)
    }

    @Test("Pattern families are deterministic, distinct, and endpoint exact")
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
        let neverCancelled: @Sendable () -> Bool = { false }
        var patternHashes: Set<String> = []
        for patternFamily in RepeatHoldEvolutionPatternFamily.allCases {
            var first = RepeatHoldEvolutionFilterState(
                patternFamily: patternFamily,
                sampleRate: sampleRate,
                totalFrameCount: frameCount
            )
            var second = RepeatHoldEvolutionFilterState(
                patternFamily: patternFamily,
                sampleRate: sampleRate,
                totalFrameCount: frameCount
            )
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
            let patternHash = ExactPCMFingerprint.stereo(
                left: renderedA.left,
                right: renderedA.right
            )
            #expect(patternHash != ExactPCMFingerprint.stereo(
                left: left,
                right: right
            ))
            patternHashes.insert(patternHash)
        }
        #expect(patternHashes.count ==
            RepeatHoldEvolutionPatternFamily.allCases.count)
    }

    @Test("Prepared phrase retains independently qualified pattern families")
    func preparedVariantsAreQualified() throws {
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
        #expect(prepared.repeatHoldEvolutionEvidence.count ==
            RepeatHoldEvolutionPatternFamily.allCases.count)
        #expect(prepared.repeatHoldEvolutions.count ==
            RepeatHoldEvolutionPatternFamily.allCases.count)
        #expect(prepared.qualifiedRepeatHoldPatternFamilies ==
            RepeatHoldEvolutionPatternFamily.allCases)
        #expect(Set(prepared.repeatHoldEvolutions.map {
            $0.evidence.variantSampleHash
        }).count == RepeatHoldEvolutionPatternFamily.allCases.count)

        for patternFamily in RepeatHoldEvolutionPatternFamily.allCases {
            let variant = try #require(prepared.repeatHoldEvolution(
                for: patternFamily
            ))
            let evidence = variant.evidence

            #expect(evidence.version == RepeatHoldEvolutionContract.version)
            #expect(evidence.patternFamily == patternFamily)
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

        let budget = try #require(AutonomousPreparationResourceBudget(
            sampleRate: 48_000,
            barCount: QualityQualificationContract.maximumPhraseBars,
            renderPassCount: QualityQualificationContract.maximumRenderPasses
        ))
        #expect(budget.withinActivationBound)
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
