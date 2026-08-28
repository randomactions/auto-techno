import AutoTechnoCore
import Foundation

/// One deterministic, phrase-boundary-safe filter movement for prolonged
/// accepted-PCM holds. It processes only the generated graph remainder; the
/// protected foundation and percussion render is recombined unchanged before
/// the existing terminal safety and live-master stages.
package enum RepeatHoldEvolutionDSPContract {
    package static let version = RepeatHoldEvolutionContract.version
    package static let maximumPreparedVariantCount = 1
    package static let highCutoffHz = 9_000.0
    package static let lowCutoffHz = 2_400.0
    package static let q = 0.707_106_781_186_547_6
    package static let maximumWetMix = 0.68
    package static let minimumHighBandReductionDB = 0.20
    package static let maximumLoudnessIncreaseDB = 0.25
}

package struct RepeatHoldEvolutionRenderBlock: Equatable, Sendable {
    package let bar: Int
    package let left: [Float]
    package let right: [Float]
    package let protectedRhythmSampleHash: String
    package let sourceGraphRemainderHighBandEnergy: Double
    package let filteredGraphRemainderHighBandEnergy: Double
    package let graphRemainderEvidenceFrameCount: Int

    package init(
        bar: Int,
        left: [Float],
        right: [Float],
        protectedRhythmSampleHash: String,
        sourceGraphRemainderHighBandEnergy: Double,
        filteredGraphRemainderHighBandEnergy: Double,
        graphRemainderEvidenceFrameCount: Int
    ) {
        self.bar = bar
        self.left = left
        self.right = right
        self.protectedRhythmSampleHash = protectedRhythmSampleHash
        self.sourceGraphRemainderHighBandEnergy =
            sourceGraphRemainderHighBandEnergy
        self.filteredGraphRemainderHighBandEnergy =
            filteredGraphRemainderHighBandEnergy
        self.graphRemainderEvidenceFrameCount =
            graphRemainderEvidenceFrameCount
    }
}

package struct AutonomousPhraseRenderProduct: Sendable {
    package let blocks: [RenderBlock]
    package let repeatHoldEvolutionBlocks: [RepeatHoldEvolutionRenderBlock]

    package init(
        blocks: [RenderBlock],
        repeatHoldEvolutionBlocks: [RepeatHoldEvolutionRenderBlock]
    ) {
        self.blocks = blocks
        self.repeatHoldEvolutionBlocks = repeatHoldEvolutionBlocks
    }
}

package struct RepeatHoldEvolutionEvidence: Equatable, Sendable {
    package let version: String
    package let qualified: Bool
    package let failureCode: String?
    package let frameCount: Int
    package let primarySampleHash: String
    package let variantSampleHash: String
    package let highBandReductionDB: Double
    package let loudnessDeltaDB: Double
    package let endpointsExact: Bool
    package let protectedRoutingExact: Bool
    package let signalSafetyValid: Bool

    package var conciseFailureCode: String {
        failureCode ?? "none"
    }
}

package struct PreparedRepeatHoldEvolutionPhrase: Equatable, Sendable {
    package let blocks: [RepeatHoldEvolutionRenderBlock]
    package let evidence: RepeatHoldEvolutionEvidence

    package init(
        blocks: [RepeatHoldEvolutionRenderBlock],
        evidence: RepeatHoldEvolutionEvidence
    ) {
        precondition(evidence.qualified)
        self.blocks = blocks
        self.evidence = evidence
    }
}

struct RepeatHoldEvolutionFilterState: Sendable {
    private let sampleRate: Double
    private let totalFrameCount: Int
    private var renderedFrameCount = 0
    private var leftFilter = TPTStateVariableFilterState()
    private var rightFilter = TPTStateVariableFilterState()
    private var sourceEvidenceLowPass = 0.0
    private var filteredEvidenceLowPass = 0.0

    init(sampleRate: Double, totalFrameCount: Int) {
        self.sampleRate = sampleRate
        self.totalFrameCount = max(1, totalFrameCount)
    }

    mutating func process(
        left: [Float],
        right: [Float],
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> (
        left: [Float],
        right: [Float],
        sourceHighBandEnergy: Double,
        filteredHighBandEnergy: Double,
        evidenceFrameCount: Int
    )? {
        guard left.count == right.count,
              renderedFrameCount + left.count <= totalFrameCount else {
            return nil
        }
        var outputLeft = [Float](repeating: 0, count: left.count)
        var outputRight = [Float](repeating: 0, count: right.count)
        let evidenceCoefficient = 1 - exp(
            -2 * Double.pi * 2_500 / sampleRate
        )
        var sourceHighBandEnergy = 0.0
        var filteredHighBandEnergy = 0.0
        for index in left.indices {
            if index.isMultiple(of: 16_384), cancellationRequested() {
                return nil
            }
            let globalIndex = renderedFrameCount + index
            let envelope: Double
            if globalIndex == 0 || globalIndex == totalFrameCount - 1 {
                envelope = 0
            } else {
                let progress = Double(globalIndex) /
                    Double(max(1, totalFrameCount - 1))
                let sine = sin(.pi * progress)
                envelope = sine * sine
            }
            let cutoff = RepeatHoldEvolutionDSPContract.highCutoffHz -
                envelope * (
                    RepeatHoldEvolutionDSPContract.highCutoffHz -
                    RepeatHoldEvolutionDSPContract.lowCutoffHz
                )
            let wet = envelope *
                RepeatHoldEvolutionDSPContract.maximumWetMix
            let dry = 1 - wet
            let leftInput = Double(left[index])
            let rightInput = Double(right[index])
            let filteredLeft = leftFilter.process(
                leftInput,
                sampleRate: sampleRate,
                cutoffHz: cutoff,
                q: RepeatHoldEvolutionDSPContract.q
            ).lowPass
            let filteredRight = rightFilter.process(
                rightInput,
                sampleRate: sampleRate,
                cutoffHz: cutoff,
                q: RepeatHoldEvolutionDSPContract.q
            ).lowPass
            outputLeft[index] = Float(leftInput * dry + filteredLeft * wet)
            outputRight[index] = Float(rightInput * dry + filteredRight * wet)
            let sourceMono = (leftInput + rightInput) * 0.5
            let filteredMono = (
                Double(outputLeft[index]) + Double(outputRight[index])
            ) * 0.5
            sourceEvidenceLowPass += (sourceMono - sourceEvidenceLowPass) *
                evidenceCoefficient
            filteredEvidenceLowPass += (
                filteredMono - filteredEvidenceLowPass
            ) * evidenceCoefficient
            let sourceHigh = sourceMono - sourceEvidenceLowPass
            let filteredHigh = filteredMono - filteredEvidenceLowPass
            sourceHighBandEnergy += sourceHigh * sourceHigh
            filteredHighBandEnergy += filteredHigh * filteredHigh
        }
        renderedFrameCount += left.count
        return (
            outputLeft,
            outputRight,
            sourceHighBandEnergy,
            filteredHighBandEnergy,
            left.count
        )
    }
}

package enum RepeatHoldEvolutionQualifier {
    package static func qualify(
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
                    code: cancellationRequested() ? "cancelled" : "analysis",
                    primaryBlocks: primaryBlocks
                )
            )
        }

        let endpointsExact = endpointsMatch(
            primaryBlocks: primaryBlocks,
            candidateBlocks: candidateBlocks
        )
        let protectedRoutingExact = zip(
            primaryBlocks,
            candidateBlocks
        ).allSatisfy {
            $0.0.protectedRhythmSampleHash ==
                $0.1.protectedRhythmSampleHash
        }
        let sourceGraphHighBandEnergy = candidateBlocks.reduce(0) {
            $0 + $1.sourceGraphRemainderHighBandEnergy
        }
        let filteredGraphHighBandEnergy = candidateBlocks.reduce(0) {
            $0 + $1.filteredGraphRemainderHighBandEnergy
        }
        let graphEvidenceFrameCount = candidateBlocks.reduce(0) {
            $0 + $1.graphRemainderEvidenceFrameCount
        }
        let highBandReduction = 10 * log10(
            max(1e-24, sourceGraphHighBandEnergy) /
                max(1e-24, filteredGraphHighBandEnergy)
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
        let effectObserved = candidateMetrics.sampleHash !=
            primaryMetrics.sampleHash &&
            graphEvidenceFrameCount == candidateMetrics.frameCount &&
            sourceGraphHighBandEnergy.isFinite &&
            filteredGraphHighBandEnergy.isFinite &&
            sourceGraphHighBandEnergy > 1e-12 &&
            highBandReduction >= RepeatHoldEvolutionDSPContract
                .minimumHighBandReductionDB
        let levelValid = loudnessDelta <=
            RepeatHoldEvolutionDSPContract.maximumLoudnessIncreaseDB
        let qualified = signalSafetyValid && endpointsExact &&
            protectedRoutingExact && effectObserved && levelValid
        let failureCode: String? = if !signalSafetyValid {
            "signal-safety"
        } else if !endpointsExact {
            "endpoints"
        } else if !protectedRoutingExact {
            "protected-routing"
        } else if !effectObserved {
            "effect-evidence"
        } else if !levelValid {
            "loudness"
        } else {
            nil
        }
        let evidence = RepeatHoldEvolutionEvidence(
            version: RepeatHoldEvolutionDSPContract.version,
            qualified: qualified,
            failureCode: failureCode,
            frameCount: candidateMetrics.frameCount,
            primarySampleHash: primaryMetrics.sampleHash,
            variantSampleHash: candidateMetrics.sampleHash,
            highBandReductionDB: highBandReduction,
            loudnessDeltaDB: loudnessDelta,
            endpointsExact: endpointsExact,
            protectedRoutingExact: protectedRoutingExact,
            signalSafetyValid: signalSafetyValid
        )
        return (
            qualified ? PreparedRepeatHoldEvolutionPhrase(
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
        code: String,
        primaryBlocks: [RenderBlock]
    ) -> RepeatHoldEvolutionEvidence {
        RepeatHoldEvolutionEvidence(
            version: RepeatHoldEvolutionDSPContract.version,
            qualified: false,
            failureCode: code,
            frameCount: primaryBlocks.reduce(0) {
                $0 + min($1.left.count, $1.right.count)
            },
            primarySampleHash: "unavailable",
            variantSampleHash: "unavailable",
            highBandReductionDB: 0,
            loudnessDeltaDB: 0,
            endpointsExact: false,
            protectedRoutingExact: false,
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
