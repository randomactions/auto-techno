import AutoTechnoCore
import Foundation

/// Bounded deterministic, phrase-boundary-safe DJ-deck movements for prolonged
/// accepted-PCM holds. Every family processes the complete pre-climax mix so
/// filter dives and grid-locked loop cuts can deliberately reshape the kick as
/// well as the generated graph. Preparation remains detached; playback receives
/// only immutable qualified PCM through the existing terminal safety path.
package enum RepeatHoldEvolutionDSPContract {
    package static let version = RepeatHoldEvolutionContract.version
    package static let maximumPreparedVariantCount =
        RepeatHoldEvolutionPatternFamily.allCases.count
    package static let highCutoffHz = 9_000.0
    package static let minimumHighBandReductionDB = 0.20
    package static let minimumLooperHighBandReductionDB = 0.08
    package static let maximumLoudnessIncreaseDB = 0.25
    package static let looperMaximumWetMix = 0.98
    package static let looperCrossfadeSeconds = 0.008
    package static let maximumLooperCaptureSeconds =
        240.0 / AutonomousSessionDirector.bpm
    /// Exact aggregate capture ceiling across the five family-owned decks:
    /// one bar + one bar + 1/2 + 1/4 + 1/8. The extra source material lets
    /// the shorter gestures jump among distinct slices instead of repeating
    /// one fixed fragment. Unlike a family-count multiplier, this remains
    /// truthful when every current family is a combined chain.
    package static let totalMaximumLooperCaptureSeconds =
        maximumLooperCaptureSeconds * 2.875

    package static func lowCutoffHz(
        for patternFamily: RepeatHoldEvolutionPatternFamily
    ) -> Double {
        switch patternFamily {
        case .oneBarCarousel: 1_150
        case .halfBarSwitchback: 780
        case .quarterBarMelodyRatchet: 1_450
        case .percussionMicroCascade: 920
        case .kickPunchCut: 640
        }
    }

    package static func maximumWetMix(
        for patternFamily: RepeatHoldEvolutionPatternFamily
    ) -> Double {
        switch patternFamily {
        case .oneBarCarousel: 0.88
        case .halfBarSwitchback: 0.92
        case .quarterBarMelodyRatchet: 0.86
        case .percussionMicroCascade: 0.94
        case .kickPunchCut: 0.90
        }
    }
}

package enum RepeatHoldEvolutionInputRouting: String, Equatable, Sendable {
    case fullMixPreClimax = "full-mix-pre-climax"
}

package struct RepeatHoldEvolutionRenderCandidate: Sendable {
    package let patternFamily: RepeatHoldEvolutionPatternFamily
    package let blocks: [RepeatHoldEvolutionRenderBlock]

    package init(
        patternFamily: RepeatHoldEvolutionPatternFamily,
        blocks: [RepeatHoldEvolutionRenderBlock]
    ) {
        self.patternFamily = patternFamily
        self.blocks = blocks
    }
}

package struct RepeatHoldEvolutionRenderBlock: Equatable, Sendable {
    package let bar: Int
    package let left: [Float]
    package let right: [Float]
    package let protectedRhythmSampleHash: String
    package let inputRouting: RepeatHoldEvolutionInputRouting
    package let sourceMixHighBandEnergy: Double
    package let transformedMixHighBandEnergy: Double
    package let wholeMixEvidenceFrameCount: Int
    package let looperCapturedFrameCount: Int
    package let looperReplayedFrameCount: Int
    package let looperExpectedReplayedFrameCount: Int
    package let looperBoundaryFrameCount: Int
    package let looperExpectedBoundaryFrameCount: Int
    package let looperSourceReuseExact: Bool
    package let looperShortestReplayFrameCount: Int

    package init(
        bar: Int,
        left: [Float],
        right: [Float],
        protectedRhythmSampleHash: String,
        inputRouting: RepeatHoldEvolutionInputRouting,
        sourceMixHighBandEnergy: Double,
        transformedMixHighBandEnergy: Double,
        wholeMixEvidenceFrameCount: Int,
        looperCapturedFrameCount: Int = 0,
        looperReplayedFrameCount: Int = 0,
        looperExpectedReplayedFrameCount: Int = 0,
        looperBoundaryFrameCount: Int = 0,
        looperExpectedBoundaryFrameCount: Int = 0,
        looperSourceReuseExact: Bool = true,
        looperShortestReplayFrameCount: Int = 0
    ) {
        self.bar = bar
        self.left = left
        self.right = right
        self.protectedRhythmSampleHash = protectedRhythmSampleHash
        self.inputRouting = inputRouting
        self.sourceMixHighBandEnergy = sourceMixHighBandEnergy
        self.transformedMixHighBandEnergy = transformedMixHighBandEnergy
        self.wholeMixEvidenceFrameCount = wholeMixEvidenceFrameCount
        self.looperCapturedFrameCount = looperCapturedFrameCount
        self.looperReplayedFrameCount = looperReplayedFrameCount
        self.looperExpectedReplayedFrameCount =
            looperExpectedReplayedFrameCount
        self.looperBoundaryFrameCount = looperBoundaryFrameCount
        self.looperExpectedBoundaryFrameCount =
            looperExpectedBoundaryFrameCount
        self.looperSourceReuseExact = looperSourceReuseExact
        self.looperShortestReplayFrameCount =
            looperShortestReplayFrameCount
    }
}

package struct AutonomousPhraseRenderProduct: Sendable {
    package let blocks: [RenderBlock]
    package let repeatHoldEvolutionCandidates:
        [RepeatHoldEvolutionRenderCandidate]

    package init(
        blocks: [RenderBlock],
        repeatHoldEvolutionCandidates:
            [RepeatHoldEvolutionRenderCandidate]
    ) {
        self.blocks = blocks
        self.repeatHoldEvolutionCandidates = repeatHoldEvolutionCandidates
    }
}

package struct RepeatHoldEvolutionEvidence: Equatable, Sendable {
    package let version: String
    package let patternFamily: RepeatHoldEvolutionPatternFamily
    package let qualified: Bool
    package let failureCode: String?
    package let frameCount: Int
    package let primarySampleHash: String
    package let variantSampleHash: String
    package let highBandReductionDB: Double
    package let loudnessDeltaDB: Double
    package let looperCapturedFrameCount: Int
    package let looperReplayedFrameCount: Int
    package let looperExpectedReplayedFrameCount: Int
    package let looperBoundaryFrameCount: Int
    package let looperExpectedBoundaryFrameCount: Int
    package let looperSourceReuseExact: Bool
    package let looperShortestReplayFrameCount: Int
    package let endpointsExact: Bool
    package let fullMixRoutingExact: Bool
    package let signalSafetyValid: Bool

    package var conciseFailureCode: String {
        failureCode ?? "none"
    }
}

package struct PreparedRepeatHoldEvolutionPhrase: Equatable, Sendable {
    package let patternFamily: RepeatHoldEvolutionPatternFamily
    package let blocks: [RepeatHoldEvolutionRenderBlock]
    package let evidence: RepeatHoldEvolutionEvidence

    package init(
        patternFamily: RepeatHoldEvolutionPatternFamily,
        blocks: [RepeatHoldEvolutionRenderBlock],
        evidence: RepeatHoldEvolutionEvidence
    ) {
        precondition(
            evidence.qualified && evidence.patternFamily == patternFamily
        )
        self.patternFamily = patternFamily
        self.blocks = blocks
        self.evidence = evidence
    }
}

struct RepeatHoldEvolutionTransformResult: Sendable {
    let left: [Float]
    let right: [Float]
    let sourceHighBandEnergy: Double
    let transformedHighBandEnergy: Double
    let evidenceFrameCount: Int
    let looperCapturedFrameCount: Int
    let looperReplayedFrameCount: Int
    let looperExpectedReplayedFrameCount: Int
    let looperBoundaryFrameCount: Int
    let looperExpectedBoundaryFrameCount: Int
    let looperSourceReuseExact: Bool
    let looperShortestReplayFrameCount: Int
}

struct RepeatHoldEvolutionTransformInput: Sendable {
    let wholeMixLeft: [Float]
    let wholeMixRight: [Float]
    let protectedRhythmLeft: [Float]
    let protectedRhythmRight: [Float]
    let melodicRemainderLeft: [Float]
    let melodicRemainderRight: [Float]
    let kick: [Float]
    let upperPercussion: [Float]

    var frameCount: Int {
        wholeMixLeft.count
    }

    var shapeValid: Bool {
        let count = wholeMixLeft.count
        return count > 0 && [
            wholeMixRight.count,
            protectedRhythmLeft.count,
            protectedRhythmRight.count,
            melodicRemainderLeft.count,
            melodicRemainderRight.count,
            kick.count,
            upperPercussion.count,
        ].allSatisfy { $0 == count }
    }

    func target(
        _ target: RepeatHoldEvolutionTarget
    ) -> (left: [Float], right: [Float]) {
        switch target {
        case .wholeMix:
            (wholeMixLeft, wholeMixRight)
        case .protectedRhythm:
            (protectedRhythmLeft, protectedRhythmRight)
        case .melodicRemainder:
            (melodicRemainderLeft, melodicRemainderRight)
        case .upperPercussion:
            (upperPercussion, upperPercussion)
        case .kick:
            (kick, kick)
        }
    }
}

struct RepeatHoldEvolutionRenderAccumulator: Sendable {
    let patternFamily: RepeatHoldEvolutionPatternFamily
    private var transformState: RepeatHoldEvolutionDeckState
    var blocks: [RepeatHoldEvolutionRenderBlock] = []
    var available = true

    init(
        patternFamily: RepeatHoldEvolutionPatternFamily,
        sampleRate: Double,
        totalFrameCount: Int,
        barCapacity: Int
    ) {
        self.patternFamily = patternFamily
        transformState = RepeatHoldEvolutionDeckState(
            patternFamily: patternFamily,
            sampleRate: sampleRate,
            totalFrameCount: totalFrameCount
        )
        blocks.reserveCapacity(barCapacity)
    }

    mutating func process(
        input: RepeatHoldEvolutionTransformInput,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> RepeatHoldEvolutionTransformResult? {
        transformState.process(
            input: input,
            cancellationRequested: cancellationRequested
        )
    }
}

private struct RepeatHoldEvolutionLoopGesture: Sendable {
    let start: Int
    let frameCount: Int
    let sourceOffset: Int
}

/// Phrase-scoped DJ-deck chain rendered entirely during detached preparation.
/// Its filter always sees the complete mix; its looper targets one canonical
/// source bus selected by the core family. Playback receives immutable sidecar
/// PCM, so no capture, lookup, allocation, or decision reaches either callback.
struct RepeatHoldEvolutionDeckState: Sendable {
    private let patternFamily: RepeatHoldEvolutionPatternFamily
    private let sampleRate: Double
    private let totalFrameCount: Int
    private let captureStart: Int
    let captureFrameCount: Int
    let shortestReplayFrameCount: Int
    private let gestures: [RepeatHoldEvolutionLoopGesture]
    private let replayGain: Double
    private let targetDeltaGain: Double
    private let crossfadeFrameCount: Int
    private var renderedFrameCount = 0
    private var capturedFrameCountTotal = 0
    private var captureLeft: [Float]
    private var captureRight: [Float]
    private var leftFilterState = 0.0
    private var rightFilterState = 0.0
    private var filterCoefficient = 0.0
    private var gestureCursor = 0
    private var sourceEvidenceLowPass = 0.0
    private var transformedEvidenceLowPass = 0.0

    init(
        patternFamily: RepeatHoldEvolutionPatternFamily,
        sampleRate: Double,
        totalFrameCount: Int
    ) {
        precondition(patternFamily.effectKind == .deckChain)
        self.patternFamily = patternFamily
        self.sampleRate = sampleRate
        self.totalFrameCount = max(1, totalFrameCount)
        let framesPerBar = max(16, Int((
            240.0 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded()))
        let halfBar = max(4, framesPerBar / 2)
        let quarterBar = max(4, framesPerBar / 4)
        let eighth = max(4, framesPerBar / 8)
        let sixteenth = max(4, framesPerBar / 16)
        let thirtySecond = max(4, framesPerBar / 32)
        let naturalCaptureFrameCount = switch patternFamily {
        case .oneBarCarousel: framesPerBar
        case .halfBarSwitchback: framesPerBar
        case .quarterBarMelodyRatchet: halfBar
        case .percussionMicroCascade: quarterBar
        case .kickPunchCut: eighth
        }
        let resolvedCaptureFrameCount = min(
            naturalCaptureFrameCount,
            max(4, self.totalFrameCount / 4)
        )
        captureFrameCount = resolvedCaptureFrameCount
        let grid = switch patternFamily {
        case .oneBarCarousel: resolvedCaptureFrameCount
        case .halfBarSwitchback: halfBar
        case .quarterBarMelodyRatchet: quarterBar
        case .percussionMicroCascade, .kickPunchCut: thirtySecond
        }
        let proposedCaptureStart = switch patternFamily {
        case .oneBarCarousel: 0
        case .halfBarSwitchback: halfBar
        case .quarterBarMelodyRatchet: framesPerBar
        case .percussionMicroCascade: framesPerBar + quarterBar
        case .kickPunchCut: framesPerBar + halfBar
        }
        let resolvedCaptureStart = Self.alignedDown(
            min(
                max(0, proposedCaptureStart),
                max(0, totalFrameCount - resolvedCaptureFrameCount - 1)
            ),
            grid: max(4, min(grid, resolvedCaptureFrameCount))
        )
        captureStart = resolvedCaptureStart
        let proposedGestures: [RepeatHoldEvolutionLoopGesture]
        switch patternFamily {
        case .oneBarCarousel:
            proposedGestures = [
                .init(start: totalFrameCount / 2,
                      frameCount: resolvedCaptureFrameCount, sourceOffset: 0),
                .init(start: totalFrameCount - resolvedCaptureFrameCount,
                      frameCount: resolvedCaptureFrameCount, sourceOffset: 0),
            ]
        case .halfBarSwitchback:
            let start = totalFrameCount / 2
            proposedGestures = (0..<4).map {
                .init(start: start + $0 * halfBar,
                      frameCount: min(halfBar, resolvedCaptureFrameCount),
                      sourceOffset: $0.isMultiple(of: 2) ? 0 : halfBar)
            }
        case .quarterBarMelodyRatchet:
            let start = totalFrameCount * 5 / 8
            let sourceOffsets = [0, eighth, quarterBar]
            proposedGestures = (0..<6).map {
                .init(start: start + $0 * quarterBar,
                      frameCount: min(quarterBar, resolvedCaptureFrameCount),
                      sourceOffset: sourceOffsets[$0 % sourceOffsets.count])
            }
        case .percussionMicroCascade:
            let start = totalFrameCount * 5 / 8
            let lengths = [
                eighth, eighth, sixteenth, sixteenth,
                thirtySecond, thirtySecond, thirtySecond, thirtySecond,
            ]
            var cursor = start
            proposedGestures = lengths.enumerated().map { ordinal, length in
                defer { cursor += length }
                return .init(
                    start: cursor,
                    frameCount: min(length, resolvedCaptureFrameCount),
                    sourceOffset: (ordinal % 4) * thirtySecond
                )
            }
        case .kickPunchCut:
            let start = totalFrameCount * 3 / 4
            let lengths = [
                sixteenth, sixteenth,
                thirtySecond, thirtySecond, thirtySecond, thirtySecond,
            ]
            var cursor = start
            proposedGestures = lengths.enumerated().map { ordinal, length in
                defer { cursor += length + (ordinal < 2 ? thirtySecond : 0) }
                return .init(
                    start: cursor,
                    frameCount: min(length, resolvedCaptureFrameCount),
                    sourceOffset: ordinal.isMultiple(of: 2) ? 0 : thirtySecond
                )
            }
        }
        let captureEnd = resolvedCaptureStart + resolvedCaptureFrameCount
        gestures = proposedGestures.map {
            RepeatHoldEvolutionLoopGesture(
                start: Self.alignedDown($0.start, grid: grid),
                frameCount: $0.frameCount,
                sourceOffset: min(
                    max(0, $0.sourceOffset),
                    max(0, resolvedCaptureFrameCount - $0.frameCount)
                )
            )
        }.filter {
            $0.start >= captureEnd &&
                $0.start + $0.frameCount <= max(1, totalFrameCount)
        }.sorted { $0.start < $1.start }
        shortestReplayFrameCount = gestures.map(\.frameCount).min() ?? 0
        switch patternFamily {
        case .oneBarCarousel:
            // A full-deck recall can replace a quieter later bar with a
            // denser opening bar. Keep the loop unmistakable while leaving
            // deterministic headroom for that arrangement-level contrast.
            replayGain = 0.86
            targetDeltaGain = 1
        case .halfBarSwitchback:
            replayGain = 0.96
            targetDeltaGain = 0.78
        case .quarterBarMelodyRatchet:
            replayGain = 0.96
            targetDeltaGain = 0.82
        case .percussionMicroCascade:
            replayGain = 0.98
            targetDeltaGain = 0.90
        case .kickPunchCut:
            replayGain = 0.95
            targetDeltaGain = 0.72
        }
        crossfadeFrameCount = max(1, min(
            max(1, shortestReplayFrameCount / 4),
            Int((sampleRate *
                RepeatHoldEvolutionDSPContract.looperCrossfadeSeconds).rounded())
        ))
        captureLeft = [Float](repeating: 0, count: resolvedCaptureFrameCount)
        captureRight = [Float](repeating: 0, count: resolvedCaptureFrameCount)
    }

    mutating func process(
        input: RepeatHoldEvolutionTransformInput,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> RepeatHoldEvolutionTransformResult? {
        guard input.shapeValid,
              renderedFrameCount + input.frameCount <= totalFrameCount else {
            return nil
        }
        let target = input.target(patternFamily.target)
        var outputLeft = [Float](repeating: 0, count: input.frameCount)
        var outputRight = [Float](repeating: 0, count: input.frameCount)
        var capturedFrameCount = 0
        var replayedFrameCount = 0
        var expectedReplayedFrameCount = 0
        var boundaryFrameCount = 0
        var expectedBoundaryFrameCount = 0
        var sourceReuseExact = true
        var shortestReplayInBlock = 0
        let evidenceCoefficient = 1 - exp(
            -2 * Double.pi * 2_500 / sampleRate
        )
        var sourceHighBandEnergy = 0.0
        var transformedHighBandEnergy = 0.0

        for index in input.wholeMixLeft.indices {
            if index.isMultiple(of: 16_384), cancellationRequested() {
                return nil
            }
            let globalIndex = renderedFrameCount + index
            let progress = Double(globalIndex) /
                Double(max(1, totalFrameCount - 1))
            let filterEnvelope = globalIndex == 0 ||
                globalIndex == totalFrameCount - 1
                ? 0 : Self.filterEnvelope(
                    progress: progress,
                    patternFamily: patternFamily
                )
            let cutoff = RepeatHoldEvolutionDSPContract.highCutoffHz -
                filterEnvelope * (
                    RepeatHoldEvolutionDSPContract.highCutoffHz -
                    RepeatHoldEvolutionDSPContract.lowCutoffHz(
                        for: patternFamily
                    )
                )
            let filterWet = filterEnvelope *
                RepeatHoldEvolutionDSPContract.maximumWetMix(
                    for: patternFamily
                )
            let filterDry = 1 - filterWet
            let wholeLeft = Double(input.wholeMixLeft[index])
            let wholeRight = Double(input.wholeMixRight[index])
            if globalIndex.isMultiple(of: 64) || filterCoefficient == 0 {
                filterCoefficient = min(
                    0.72,
                    1 - exp(-2 * Double.pi * cutoff / sampleRate)
                )
            }
            leftFilterState += (wholeLeft - leftFilterState) *
                filterCoefficient
            rightFilterState += (wholeRight - rightFilterState) *
                filterCoefficient
            let filteredLeft = leftFilterState
            let filteredRight = rightFilterState
            var deckLeft = wholeLeft * filterDry + filteredLeft * filterWet
            var deckRight = wholeRight * filterDry + filteredRight * filterWet
            if globalIndex >= captureStart,
               globalIndex < captureStart + captureFrameCount {
                let captureIndex = globalIndex - captureStart
                if patternFamily.target == .wholeMix {
                    // The whole-deck family captures after its filter, matching
                    // a DJ loop placed downstream of the channel filter.
                    captureLeft[captureIndex] = Float(deckLeft)
                    captureRight[captureIndex] = Float(deckRight)
                } else {
                    captureLeft[captureIndex] = target.left[index]
                    captureRight[captureIndex] = target.right[index]
                }
                capturedFrameCount += 1
                capturedFrameCountTotal += 1
            }
            while gestureCursor < gestures.count,
                  globalIndex >= gestures[gestureCursor].start +
                    gestures[gestureCursor].frameCount {
                gestureCursor += 1
            }
            if gestureCursor < gestures.count,
               globalIndex >= gestures[gestureCursor].start {
                let gesture = gestures[gestureCursor]
                let gestureIndex = globalIndex - gesture.start
                let sourceIndex = gesture.sourceOffset + gestureIndex
                shortestReplayInBlock = shortestReplayInBlock == 0
                    ? gesture.frameCount
                    : min(shortestReplayInBlock, gesture.frameCount)
                if gestureIndex == 0 ||
                    gestureIndex == gesture.frameCount - 1 {
                    // Both chains are exactly dry at the gesture endpoints;
                    // the whole-phrase filter is still allowed to be active.
                    expectedBoundaryFrameCount += 1
                    boundaryFrameCount += 1
                } else {
                    expectedReplayedFrameCount += 1
                    if sourceIndex >= capturedFrameCountTotal ||
                       sourceIndex >= captureLeft.count ||
                       sourceIndex >= captureRight.count {
                        sourceReuseExact = false
                    } else {
                        let edgeDistance = min(
                            gestureIndex,
                            gesture.frameCount - 1 - gestureIndex
                        )
                        let ramp = min(
                            1,
                            Double(edgeDistance) /
                                Double(max(1, crossfadeFrameCount))
                        )
                        let smoothRamp = ramp * ramp * (3 - 2 * ramp)
                        let loopWet = smoothRamp *
                            RepeatHoldEvolutionDSPContract.looperMaximumWetMix
                        let replayLeft = Double(captureLeft[sourceIndex]) *
                            replayGain
                        let replayRight = Double(captureRight[sourceIndex]) *
                            replayGain
                        if patternFamily.target == .wholeMix {
                            deckLeft = deckLeft * (1 - loopWet) +
                                replayLeft * loopWet
                            deckRight = deckRight * (1 - loopWet) +
                                replayRight * loopWet
                        } else {
                            let targetLeft = Double(target.left[index])
                            let targetRight = Double(target.right[index])
                            deckLeft += (replayLeft - targetLeft) * loopWet *
                                targetDeltaGain
                            deckRight += (replayRight - targetRight) * loopWet *
                                targetDeltaGain
                        }
                        replayedFrameCount += 1
                    }
                }
            }
            outputLeft[index] = Float(deckLeft)
            outputRight[index] = Float(deckRight)
            let sourceMono = (wholeLeft + wholeRight) * 0.5
            let transformedMono = (deckLeft + deckRight) * 0.5
            sourceEvidenceLowPass += (sourceMono - sourceEvidenceLowPass) *
                evidenceCoefficient
            transformedEvidenceLowPass += (
                transformedMono - transformedEvidenceLowPass
            ) * evidenceCoefficient
            let sourceHigh = sourceMono - sourceEvidenceLowPass
            let transformedHigh = transformedMono - transformedEvidenceLowPass
            sourceHighBandEnergy += sourceHigh * sourceHigh
            transformedHighBandEnergy += transformedHigh * transformedHigh
        }
        renderedFrameCount += input.frameCount
        return RepeatHoldEvolutionTransformResult(
            left: outputLeft,
            right: outputRight,
            sourceHighBandEnergy: sourceHighBandEnergy,
            transformedHighBandEnergy: transformedHighBandEnergy,
            evidenceFrameCount: input.frameCount,
            looperCapturedFrameCount: capturedFrameCount,
            looperReplayedFrameCount: replayedFrameCount,
            looperExpectedReplayedFrameCount: expectedReplayedFrameCount,
            looperBoundaryFrameCount: boundaryFrameCount,
            looperExpectedBoundaryFrameCount: expectedBoundaryFrameCount,
            looperSourceReuseExact: sourceReuseExact,
            looperShortestReplayFrameCount: shortestReplayInBlock
        )
    }

    private static func filterEnvelope(
        progress: Double,
        patternFamily: RepeatHoldEvolutionPatternFamily
    ) -> Double {
        let cycles: Double = switch patternFamily {
        case .oneBarCarousel: 1
        case .halfBarSwitchback: 2
        case .quarterBarMelodyRatchet: 3
        case .percussionMicroCascade: 4
        case .kickPunchCut: 2
        }
        let delayedProgress: Double
        switch patternFamily {
        case .percussionMicroCascade:
            delayedProgress = progress < 0.35
                ? 0 : (progress - 0.35) / 0.65
        case .kickPunchCut:
            delayedProgress = progress < 0.20
                ? 0 : (progress - 0.20) / 0.80
        default:
            delayedProgress = progress
        }
        guard delayedProgress > 0, delayedProgress < 1 else { return 0 }
        let sine = sin(.pi * cycles * delayedProgress)
        return sine * sine
    }

    private static func alignedDown(_ frame: Int, grid: Int) -> Int {
        guard grid > 0 else { return frame }
        return max(0, frame / grid * grid)
    }
}

package enum RepeatHoldEvolutionQualifier {
    package static func qualify(
        patternFamily: RepeatHoldEvolutionPatternFamily,
        primaryBlocks: [RenderBlock],
        candidateBlocks: [RepeatHoldEvolutionRenderBlock],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> (
        prepared: PreparedRepeatHoldEvolutionPhrase?,
        evidence: RepeatHoldEvolutionEvidence
    ) {
        let shapeValid = !primaryBlocks.isEmpty &&
            primaryBlocks.count == candidateBlocks.count &&
            zip(primaryBlocks, candidateBlocks).allSatisfy { primary, candidate in
                primary.bar == candidate.bar &&
                    primary.left.count == candidate.left.count &&
                    primary.right.count == candidate.right.count &&
                    candidate.left.count == candidate.right.count
            }
        guard shapeValid, !cancellationRequested() else {
            let evidence = unavailableEvidence(
                patternFamily: patternFamily,
                code: cancellationRequested() ? "cancelled" : "shape",
                primaryBlocks: primaryBlocks
            )
            return (nil, evidence)
        }

        let projectedBlocks = zip(primaryBlocks, candidateBlocks).map {
            $0.0.replacingPCM(left: $0.1.left, right: $0.1.right)
        }
        guard let primaryMetrics = metrics(
            blocks: primaryBlocks.map { ($0.left, $0.right) },
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ), let candidateMetrics = metrics(
            blocks: candidateBlocks.map { ($0.left, $0.right) },
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else {
            return (
                nil,
                unavailableEvidence(
                    patternFamily: patternFamily,
                    code: cancellationRequested() ? "cancelled" : "analysis",
                    primaryBlocks: primaryBlocks
                )
            )
        }

        let endpointsExact = endpointsMatch(
            primaryBlocks: primaryBlocks,
            candidateBlocks: candidateBlocks
        )
        let fullMixRoutingExact = zip(
            primaryBlocks,
            candidateBlocks
        ).allSatisfy {
            $0.0.protectedRhythmSampleHash ==
                $0.1.protectedRhythmSampleHash &&
                $0.1.inputRouting == .fullMixPreClimax
        }
        let sourceMixHighBandEnergy = candidateBlocks.reduce(0) {
            $0 + $1.sourceMixHighBandEnergy
        }
        let transformedMixHighBandEnergy = candidateBlocks.reduce(0) {
            $0 + $1.transformedMixHighBandEnergy
        }
        let wholeMixEvidenceFrameCount = candidateBlocks.reduce(0) {
            $0 + $1.wholeMixEvidenceFrameCount
        }
        let looperCapturedFrameCount = candidateBlocks.reduce(0) {
            $0 + $1.looperCapturedFrameCount
        }
        let looperReplayedFrameCount = candidateBlocks.reduce(0) {
            $0 + $1.looperReplayedFrameCount
        }
        let looperExpectedReplayedFrameCount = candidateBlocks.reduce(0) {
            $0 + $1.looperExpectedReplayedFrameCount
        }
        let looperBoundaryFrameCount = candidateBlocks.reduce(0) {
            $0 + $1.looperBoundaryFrameCount
        }
        let looperExpectedBoundaryFrameCount = candidateBlocks.reduce(0) {
            $0 + $1.looperExpectedBoundaryFrameCount
        }
        let looperSourceReuseExact = candidateBlocks.allSatisfy(
            \.looperSourceReuseExact
        )
        let looperShortestReplayFrameCount = candidateBlocks.map(
            \.looperShortestReplayFrameCount
        ).filter { $0 > 0 }.min() ?? 0
        let highBandReduction = 10 * log10(
            max(1e-24, sourceMixHighBandEnergy) /
                max(1e-24, transformedMixHighBandEnergy)
        )
        let loudnessDelta = decibels(
            numerator: candidateMetrics.rms,
            denominator: primaryMetrics.rms
        )
        let maximumTruePeak = projectedBlocks.map(\.truePeakEstimate).max() ?? 1
        let maximumBoundaryDelta = AudioQualityReport.maximumBoundaryDelta(
            leftBlocks: candidateBlocks.map(\.left),
            rightBlocks: candidateBlocks.map(\.right),
            precedingFrame: primaryBlocks.last.flatMap { block in
                guard let left = block.left.last,
                      let right = block.right.last else { return nil }
                return UpperTimbreStereoFrame(left: left, right: right)
            }
        )
        let signalSafetyValid = candidateMetrics.finite &&
            maximumTruePeak <= 0.95 &&
            abs(candidateMetrics.dcOffset) < 0.05 &&
            candidateMetrics.lowStereoCorrelation > 0.94 &&
            maximumBoundaryDelta < 0.65
        let effectObserved: Bool
        switch patternFamily.effectKind {
        case .filter:
            effectObserved = candidateMetrics.sampleHash !=
                primaryMetrics.sampleHash &&
                wholeMixEvidenceFrameCount == candidateMetrics.frameCount &&
                sourceMixHighBandEnergy.isFinite &&
                transformedMixHighBandEnergy.isFinite &&
                sourceMixHighBandEnergy > 1e-12 &&
                highBandReduction >= RepeatHoldEvolutionDSPContract
                    .minimumHighBandReductionDB
        case .looper:
            effectObserved = candidateMetrics.sampleHash !=
                primaryMetrics.sampleHash &&
                wholeMixEvidenceFrameCount == candidateMetrics.frameCount &&
                looperCapturedFrameCount > 0 &&
                looperReplayedFrameCount > 0 &&
                looperReplayedFrameCount ==
                    looperExpectedReplayedFrameCount &&
                looperBoundaryFrameCount > 0 &&
                looperBoundaryFrameCount ==
                    looperExpectedBoundaryFrameCount &&
                looperSourceReuseExact
        case .deckChain:
            effectObserved = candidateMetrics.sampleHash !=
                primaryMetrics.sampleHash &&
                wholeMixEvidenceFrameCount == candidateMetrics.frameCount &&
                sourceMixHighBandEnergy.isFinite &&
                transformedMixHighBandEnergy.isFinite &&
                sourceMixHighBandEnergy > 1e-12 &&
                highBandReduction >= RepeatHoldEvolutionDSPContract
                    .minimumLooperHighBandReductionDB &&
                looperCapturedFrameCount > 0 &&
                looperReplayedFrameCount > 0 &&
                looperReplayedFrameCount ==
                    looperExpectedReplayedFrameCount &&
                looperBoundaryFrameCount > 0 &&
                looperBoundaryFrameCount ==
                    looperExpectedBoundaryFrameCount &&
                looperSourceReuseExact &&
                looperShortestReplayFrameCount > 0
        }
        let levelValid = loudnessDelta <=
            RepeatHoldEvolutionDSPContract.maximumLoudnessIncreaseDB
        let qualified = signalSafetyValid && endpointsExact &&
            fullMixRoutingExact && effectObserved && levelValid
        let failureCode: String? = if !signalSafetyValid {
            "signal-safety"
        } else if !endpointsExact {
            "endpoints"
        } else if !fullMixRoutingExact {
            "full-mix-routing"
        } else if !effectObserved {
            patternFamily.effectKind == .filter
                ? "filter-evidence" : "deck-chain-evidence"
        } else if !levelValid {
            "loudness"
        } else {
            nil
        }
        let evidence = RepeatHoldEvolutionEvidence(
            version: RepeatHoldEvolutionDSPContract.version,
            patternFamily: patternFamily,
            qualified: qualified,
            failureCode: failureCode,
            frameCount: candidateMetrics.frameCount,
            primarySampleHash: primaryMetrics.sampleHash,
            variantSampleHash: candidateMetrics.sampleHash,
            highBandReductionDB: highBandReduction,
            loudnessDeltaDB: loudnessDelta,
            looperCapturedFrameCount: looperCapturedFrameCount,
            looperReplayedFrameCount: looperReplayedFrameCount,
            looperExpectedReplayedFrameCount:
                looperExpectedReplayedFrameCount,
            looperBoundaryFrameCount: looperBoundaryFrameCount,
            looperExpectedBoundaryFrameCount:
                looperExpectedBoundaryFrameCount,
            looperSourceReuseExact: looperSourceReuseExact,
            looperShortestReplayFrameCount:
                looperShortestReplayFrameCount,
            endpointsExact: endpointsExact,
            fullMixRoutingExact: fullMixRoutingExact,
            signalSafetyValid: signalSafetyValid
        )
        return (
            qualified ? PreparedRepeatHoldEvolutionPhrase(
                patternFamily: patternFamily,
                blocks: candidateBlocks,
                evidence: evidence
            ) : nil,
            evidence
        )
    }

    private static func endpointsMatch(
        primaryBlocks: [RenderBlock],
        candidateBlocks: [RepeatHoldEvolutionRenderBlock]
    ) -> Bool {
        guard let primaryFirst = primaryBlocks.first,
              let primaryLast = primaryBlocks.last,
              let candidateFirst = candidateBlocks.first,
              let candidateLast = candidateBlocks.last,
              let primaryFirstLeft = primaryFirst.left.first,
              let primaryFirstRight = primaryFirst.right.first,
              let primaryLastLeft = primaryLast.left.last,
              let primaryLastRight = primaryLast.right.last,
              let candidateFirstLeft = candidateFirst.left.first,
              let candidateFirstRight = candidateFirst.right.first,
              let candidateLastLeft = candidateLast.left.last,
              let candidateLastRight = candidateLast.right.last else {
            return false
        }
        return primaryFirstLeft.bitPattern == candidateFirstLeft.bitPattern &&
            primaryFirstRight.bitPattern == candidateFirstRight.bitPattern &&
            primaryLastLeft.bitPattern == candidateLastLeft.bitPattern &&
            primaryLastRight.bitPattern == candidateLastRight.bitPattern
    }

    private static func unavailableEvidence(
        patternFamily: RepeatHoldEvolutionPatternFamily,
        code: String,
        primaryBlocks: [RenderBlock]
    ) -> RepeatHoldEvolutionEvidence {
        RepeatHoldEvolutionEvidence(
            version: RepeatHoldEvolutionDSPContract.version,
            patternFamily: patternFamily,
            qualified: false,
            failureCode: code,
            frameCount: primaryBlocks.reduce(0) {
                $0 + min($1.left.count, $1.right.count)
            },
            primarySampleHash: "unavailable",
            variantSampleHash: "unavailable",
            highBandReductionDB: 0,
            loudnessDeltaDB: 0,
            looperCapturedFrameCount: 0,
            looperReplayedFrameCount: 0,
            looperExpectedReplayedFrameCount: 0,
            looperBoundaryFrameCount: 0,
            looperExpectedBoundaryFrameCount: 0,
            looperSourceReuseExact: false,
            looperShortestReplayFrameCount: 0,
            endpointsExact: false,
            fullMixRoutingExact: false,
            signalSafetyValid: false
        )
    }

    private struct LightweightMetrics {
        let frameCount: Int
        let rms: Double
        let dcOffset: Double
        let lowStereoCorrelation: Double
        let finite: Bool
        let sampleHash: String
    }

    private static func metrics(
        blocks: [([Float], [Float])],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> LightweightMetrics? {
        guard sampleRate.isFinite, sampleRate > 0 else { return nil }
        let lowCorrelationCoefficient = AudioQualityReport.lowPassCoefficient(
            sampleRate: sampleRate
        )
        var frameCount = 0
        var energy = 0.0
        var sum = 0.0
        var lowLeft = 0.0
        var lowRight = 0.0
        var lowCross = 0.0
        var lowLeftEnergy = 0.0
        var lowRightEnergy = 0.0
        var finite = !blocks.isEmpty
        var hash: UInt64 = 0xcbf29ce484222325
        for channel in 0..<2 {
            for block in blocks {
                let samples = channel == 0 ? block.0 : block.1
                for (index, sample) in samples.enumerated() {
                    if index.isMultiple(of: 16_384), cancellationRequested() {
                        return nil
                    }
                    var bits = sample.bitPattern
                    for _ in 0..<4 {
                        hash ^= UInt64(bits & 0xff)
                        hash &*= 0x100000001b3
                        bits >>= 8
                    }
                }
            }
        }
        for block in blocks {
            guard block.0.count == block.1.count else { return nil }
            for index in block.0.indices {
                if frameCount.isMultiple(of: 16_384),
                   cancellationRequested() { return nil }
                let left = Double(block.0[index])
                let right = Double(block.1[index])
                finite = finite && left.isFinite && right.isFinite
                energy += left * left + right * right
                sum += left + right
                lowLeft += (left - lowLeft) * lowCorrelationCoefficient
                lowRight += (right - lowRight) * lowCorrelationCoefficient
                lowCross += lowLeft * lowRight
                lowLeftEnergy += lowLeft * lowLeft
                lowRightEnergy += lowRight * lowRight
                frameCount += 1
            }
        }
        guard frameCount > 0 else { return nil }
        return LightweightMetrics(
            frameCount: frameCount,
            rms: sqrt(energy / Double(frameCount * 2)),
            dcOffset: sum / Double(frameCount * 2),
            lowStereoCorrelation: lowCross / sqrt(max(
                0.0000001,
                lowLeftEnergy * lowRightEnergy
            )),
            finite: finite,
            sampleHash: fixedWidthFingerprintHex(hash)
        )
    }

    private static func decibels(
        numerator: Double,
        denominator: Double
    ) -> Double {
        20 * log10(max(1e-12, numerator) / max(1e-12, denominator))
    }
}
