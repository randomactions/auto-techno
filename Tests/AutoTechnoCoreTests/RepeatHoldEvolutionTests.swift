import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Bounded repeat hold evolution", .serialized)
struct RepeatHoldEvolutionTests {
    @Test("Core rotates only qualified deck chains after two repeats")
    func boundaryPolicyIsBounded() {
        let families = RepeatHoldEvolutionPatternFamily.allCases
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 1, successorPrepared: false,
            qualifiedPatternFamilies: families
        ) == .exactAcceptedPCM)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 2, successorPrepared: false,
            qualifiedPatternFamilies: families
        ) == .qualifiedPattern(.oneBarCarousel))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 3, successorPrepared: false,
            qualifiedPatternFamilies: families
        ) == .qualifiedPattern(.halfBarSwitchback))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 4, successorPrepared: false,
            qualifiedPatternFamilies: families
        ) == .qualifiedPattern(.quarterBarMelodyRatchet))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 5, successorPrepared: false,
            qualifiedPatternFamilies: families
        ) == .qualifiedPattern(.percussionMicroCascade))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 6, successorPrepared: false,
            qualifiedPatternFamilies: families
        ) == .qualifiedPattern(.kickPunchCut))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 7, successorPrepared: false,
            qualifiedPatternFamilies: families
        ) == .qualifiedPattern(.oneBarCarousel))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 3, successorPrepared: false,
            qualifiedPatternFamilies: [.oneBarCarousel, .kickPunchCut]
        ) == .qualifiedPattern(.kickPunchCut))
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 9, successorPrepared: true,
            qualifiedPatternFamilies: families
        ) == .exactAcceptedPCM)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 9, successorPrepared: false,
            qualifiedPatternFamilies: []
        ) == .exactAcceptedPCM)
        #expect(RepeatHoldEvolutionBoundaryPolicy.decide(
            coherentRepeatCount: 9, successorPrepared: false,
            qualifiedPatternFamilies: families,
            exactAcceptedPCMRequired: true
        ) == .exactAcceptedPCM)
        #expect(!RepeatHoldEvolutionPlaybackMode.qualifiedPattern(
            .percussionMicroCascade
        ).participatesInCanonicalLiveFeedback)
    }

    @Test("Deck chains are deterministic, distinct, target-specific, and grid exact")
    func deckChainsAreDeterministicAndGridExact() throws {
        let sampleRate = 8_000.0
        let framesPerBar = Int((
            240.0 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded())
        let frameCount = framesPerBar * 4
        let input = makeInput(frameCount: frameCount, sampleRate: sampleRate)
        let neverCancelled: @Sendable () -> Bool = { false }
        let sourceHash = ExactPCMFingerprint.stereo(
            left: input.wholeMixLeft, right: input.wholeMixRight
        )
        let expectedCapture: [RepeatHoldEvolutionPatternFamily: Int] = [
            .oneBarCarousel: framesPerBar,
            .halfBarSwitchback: framesPerBar,
            .quarterBarMelodyRatchet: framesPerBar / 2,
            .percussionMicroCascade: framesPerBar / 4,
            .kickPunchCut: framesPerBar / 8,
        ]
        let expectedShortest: [RepeatHoldEvolutionPatternFamily: Int] = [
            .oneBarCarousel: framesPerBar,
            .halfBarSwitchback: framesPerBar / 2,
            .quarterBarMelodyRatchet: framesPerBar / 4,
            .percussionMicroCascade: framesPerBar / 32,
            .kickPunchCut: framesPerBar / 32,
        ]
        var hashes: Set<String> = []
        for family in RepeatHoldEvolutionPatternFamily.allCases {
            #expect(family.effectKind == .deckChain)
            var first = RepeatHoldEvolutionDeckState(
                patternFamily: family, sampleRate: sampleRate,
                totalFrameCount: frameCount
            )
            var second = RepeatHoldEvolutionDeckState(
                patternFamily: family, sampleRate: sampleRate,
                totalFrameCount: frameCount
            )
            #expect(first.captureFrameCount == expectedCapture[family])
            #expect(first.shortestReplayFrameCount == expectedShortest[family])
            let renderedAResult = first.process(
                input: input, cancellationRequested: neverCancelled
            )
            let renderedBResult = second.process(
                input: input, cancellationRequested: neverCancelled
            )
            let renderedA = try #require(renderedAResult)
            let renderedB = try #require(renderedBResult)
            #expect(renderedA.left == renderedB.left)
            #expect(renderedA.right == renderedB.right)
            #expect(renderedA.left.first?.bitPattern ==
                input.wholeMixLeft.first?.bitPattern)
            #expect(renderedA.right.first?.bitPattern ==
                input.wholeMixRight.first?.bitPattern)
            #expect(renderedA.left.last?.bitPattern ==
                input.wholeMixLeft.last?.bitPattern)
            #expect(renderedA.right.last?.bitPattern ==
                input.wholeMixRight.last?.bitPattern)
            #expect(renderedA.looperCapturedFrameCount == expectedCapture[family])
            #expect(renderedA.looperReplayedFrameCount > 0)
            #expect(renderedA.looperReplayedFrameCount ==
                renderedA.looperExpectedReplayedFrameCount)
            #expect(renderedA.looperBoundaryFrameCount ==
                renderedA.looperExpectedBoundaryFrameCount)
            #expect(renderedA.looperSourceReuseExact)
            #expect(renderedA.looperShortestReplayFrameCount ==
                expectedShortest[family])
            #expect(renderedA.sourceHighBandEnergy >
                renderedA.transformedHighBandEnergy)
            let hash = ExactPCMFingerprint.stereo(
                left: renderedA.left, right: renderedA.right
            )
            #expect(hash != sourceHash)
            hashes.insert(hash)
        }
        #expect(hashes.count == RepeatHoldEvolutionPatternFamily.allCases.count)
        #expect(RepeatHoldEvolutionPatternFamily.percussionMicroCascade.target ==
            .upperPercussion)
        #expect(RepeatHoldEvolutionPatternFamily.kickPunchCut.target == .kick)
    }

    @Test("Every chain filter audibly transforms a kick-only full mix")
    func wholeMixFilterIncludesKick() throws {
        let sampleRate = 8_000.0
        let framesPerBar = Int((
            240.0 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded())
        let frameCount = framesPerBar * 4
        let kick = (0..<frameCount).map { index -> Float in
            let phase = index % max(1, framesPerBar / 4)
            guard phase < 600 else { return 0 }
            return Float(sin(2 * Double.pi * 72 * Double(phase) / sampleRate) *
                exp(-Double(phase) / 170) * 0.34)
        }
        let zeros = [Float](repeating: 0, count: frameCount)
        let input = RepeatHoldEvolutionTransformInput(
            wholeMixLeft: kick, wholeMixRight: kick,
            protectedRhythmLeft: kick, protectedRhythmRight: kick,
            melodicRemainderLeft: zeros, melodicRemainderRight: zeros,
            kick: kick, upperPercussion: zeros
        )
        let neverCancelled: @Sendable () -> Bool = { false }
        let sourceHash = ExactPCMFingerprint.stereo(left: kick, right: kick)
        for family in RepeatHoldEvolutionPatternFamily.allCases {
            var state = RepeatHoldEvolutionDeckState(
                patternFamily: family, sampleRate: sampleRate,
                totalFrameCount: frameCount
            )
            let renderedResult = state.process(
                input: input, cancellationRequested: neverCancelled
            )
            let rendered = try #require(renderedResult)
            #expect(ExactPCMFingerprint.stereo(
                left: rendered.left, right: rendered.right
            ) != sourceHash)
        }
    }

    @Test("Prepared phrase retains independently qualified deck chains")
    func preparedVariantsAreQualified() throws {
        let director = AutonomousSessionDirector(rootSeed: 19)
        let state = director.initialState()
        let neverCancelled: @Sendable () -> Bool = { false }
        let preparedResult =
            AutonomousPhrasePreparer.prepareIfNotCancelled(
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
        for evidence in prepared.repeatHoldEvolutionEvidence {
            let replaySummary =
                "captured=\(evidence.looperCapturedFrameCount) " +
                "replayed=\(evidence.looperReplayedFrameCount)/" +
                "\(evidence.looperExpectedReplayedFrameCount) " +
                "boundary=\(evidence.looperBoundaryFrameCount)/" +
                "\(evidence.looperExpectedBoundaryFrameCount) " +
                "shortest=\(evidence.looperShortestReplayFrameCount)"
            let safetySummary =
                "endpoints=\(evidence.endpointsExact) " +
                "routing=\(evidence.fullMixRoutingExact) " +
                "safety=\(evidence.signalSafetyValid)"
            let failureSummary =
                "family=\(evidence.patternFamily.rawValue) " +
                "failure=\(evidence.conciseFailureCode) " +
                "high=\(evidence.highBandReductionDB) " +
                "loudness=\(evidence.loudnessDeltaDB) " +
                replaySummary + " " + safetySummary
            #expect(
                evidence.qualified,
                Comment(rawValue: failureSummary)
            )
        }
        #expect(prepared.repeatHoldEvolutionEvidence.count ==
            RepeatHoldEvolutionPatternFamily.allCases.count)
        #expect(prepared.repeatHoldEvolutions.count ==
            RepeatHoldEvolutionPatternFamily.allCases.count)
        #expect(prepared.qualifiedRepeatHoldPatternFamilies ==
            RepeatHoldEvolutionPatternFamily.allCases)
        #expect(Set(prepared.repeatHoldEvolutions.map {
            $0.evidence.variantSampleHash
        }).count == RepeatHoldEvolutionPatternFamily.allCases.count)
        for family in RepeatHoldEvolutionPatternFamily.allCases {
            let variant = try #require(prepared.repeatHoldEvolution(for: family))
            let evidence = variant.evidence
            #expect(evidence.version == RepeatHoldEvolutionContract.version)
            #expect(evidence.patternFamily == family)
            #expect(evidence.qualified)
            #expect(evidence.signalSafetyValid)
            #expect(evidence.endpointsExact)
            #expect(evidence.fullMixRoutingExact)
            #expect(evidence.highBandReductionDB >=
                RepeatHoldEvolutionDSPContract.minimumLooperHighBandReductionDB)
            #expect(evidence.looperCapturedFrameCount > 0)
            #expect(evidence.looperReplayedFrameCount > 0)
            #expect(evidence.looperReplayedFrameCount ==
                evidence.looperExpectedReplayedFrameCount)
            #expect(evidence.looperBoundaryFrameCount ==
                evidence.looperExpectedBoundaryFrameCount)
            #expect(evidence.looperSourceReuseExact)
            #expect(evidence.looperShortestReplayFrameCount > 0)
            #expect(evidence.loudnessDeltaDB <=
                RepeatHoldEvolutionDSPContract.maximumLoudnessIncreaseDB)
            #expect(evidence.primarySampleHash ==
                prepared.audioPreflight.quality.sampleHash)
            #expect(evidence.variantSampleHash != evidence.primarySampleHash)
            #expect(variant.blocks.count == prepared.blocks.count)
            #expect(variant.blocks.allSatisfy {
                $0.inputRouting == .fullMixPreClimax
            })
        }
        let budget = try #require(AutonomousPreparationResourceBudget(
            sampleRate: 48_000,
            barCount: QualityQualificationContract.maximumPhraseBars,
            renderPassCount: QualityQualificationContract.maximumRenderPasses
        ))
        #expect(budget.withinActivationBound)
        #expect(budget.repeatHoldWorkingPCMByteCount > 0)
    }

    private func makeInput(
        frameCount: Int,
        sampleRate: Double
    ) -> RepeatHoldEvolutionTransformInput {
        let kickPeriod = max(1, Int(sampleRate * 60 /
            AutonomousSessionDirector.bpm))
        let kick = (0..<frameCount).map { index -> Float in
            let phase = index % kickPeriod
            guard phase < 700 else { return 0 }
            return Float(sin(2 * Double.pi * 74 * Double(phase) / sampleRate) *
                exp(-Double(phase) / 190) * 0.28)
        }
        let percussion = (0..<frameCount).map { index -> Float in
            let phase = index % max(1, kickPeriod / 2)
            guard phase < 100 else { return 0 }
            return Float(sin(2 * Double.pi * 2_600 * Double(phase) / sampleRate) *
                exp(-Double(phase) / 28) * 0.08)
        }
        let melodicLeft = (0..<frameCount).map {
            sample(index: $0, sampleRate: sampleRate,
                   lowFrequency: 187, lowGain: 0.10,
                   highFrequency: 1_700, highGain: 0.05)
        }
        let melodicRight = (0..<frameCount).map {
            sample(index: $0, sampleRate: sampleRate,
                   lowFrequency: 233, lowGain: 0.09,
                   highFrequency: 1_300, highGain: 0.04)
        }
        let protected = zip(kick, percussion).map(+)
        return RepeatHoldEvolutionTransformInput(
            wholeMixLeft: zip(protected, melodicLeft).map(+),
            wholeMixRight: zip(protected, melodicRight).map(+),
            protectedRhythmLeft: protected,
            protectedRhythmRight: protected,
            melodicRemainderLeft: melodicLeft,
            melodicRemainderRight: melodicRight,
            kick: kick,
            upperPercussion: percussion
        )
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
        return Float(
            sin(2 * Double.pi * lowFrequency * time) * lowGain +
                sin(2 * Double.pi * highFrequency * time) * highGain
        )
    }
}
