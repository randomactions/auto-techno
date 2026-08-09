import Foundation

package struct AudioQualityReport: Equatable, Sendable {
    package static let lowStereoCorrelationCutoffHz = 140.0
    package static let loudnessStandard = BS1770LoudnessMeasurement.standard
    package static let truePeakStandard = BS1770AudioEvidence.truePeakStandard
    package let analyzedFrameCount: Int
    package let peak: Float
    package let truePeakEstimate: Float
    package let truePeakDBTP: Float
    package let rms: Float
    /// Compatibility projection. Its value is now the BS.1770-5 integrated
    /// programme loudness, not an RMS-derived approximation.
    package let loudnessEstimate: Float
    package let dcOffset: Float
    package let stereoCorrelation: Float
    package let lowStereoCorrelation: Float
    package let maxBoundaryDelta: Float
    package let finite: Bool
    package let sampleHash: String
    package let musical: MusicalQualityMetrics
    /// Conservative sum of each streaming analyzer's peak scratch storage,
    /// excluding the immutable source RenderBlocks required for playback.
    package let analysisPeakWorkingByteCount: Int

    package init(blocks: [RenderBlock], sampleRate: Double) {
        guard let report = Self(
            blocks: blocks,
            sampleRate: sampleRate,
            cancellationRequested: { false }
        ) else {
            preconditionFailure("Non-cancellable audio report stopped unexpectedly")
        }
        self = report
    }

    package init?(
        blocks: [RenderBlock],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) {
        guard !cancellationRequested() else { return nil }
        var computedFinite = true
        var count = 0
        for block in blocks {
            guard !cancellationRequested() else { return nil }
            computedFinite = computedFinite &&
                block.left.count == block.right.count
            for (index, sample) in block.left.enumerated() {
                if index.isMultiple(of: 16_384), cancellationRequested() {
                    return nil
                }
                computedFinite = computedFinite && sample.isFinite
            }
            for (index, sample) in block.right.enumerated() {
                if index.isMultiple(of: 16_384), cancellationRequested() {
                    return nil
                }
                computedFinite = computedFinite && sample.isFinite
            }
            count += min(block.left.count, block.right.count)
        }
        guard count > 0 else {
            analyzedFrameCount = 0
            peak = 0
            truePeakEstimate = 0
            truePeakDBTP = -120
            rms = 0
            loudnessEstimate = -120
            dcOffset = 0
            stereoCorrelation = 1
            lowStereoCorrelation = 1
            maxBoundaryDelta = 0
            finite = computedFinite
            sampleHash = "0000000000000000"
            musical = MusicalQualityMetrics(left: [], right: [], sampleRate: sampleRate)
            analysisPeakWorkingByteCount =
                musical.perceptualEvidence.peakWorkingByteCount +
                musical.loudnessPeakWorkingByteCount +
                2 * 12 * MemoryLayout<Double>.stride
            return
        }
        analyzedFrameCount = count

        var computedPeak: Float = 0
        var energy = 0.0
        var sum = 0.0
        var cross = 0.0
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        var lowLeft = 0.0
        var lowRight = 0.0
        var lowCross = 0.0
        var lowLeftEnergy = 0.0
        var lowRightEnergy = 0.0
        let lowPassCoefficient = Self.lowPassCoefficient(sampleRate: sampleRate)
        var analyzed = 0
        for block in blocks {
            let blockCount = min(block.left.count, block.right.count)
            for index in 0..<blockCount {
                if analyzed.isMultiple(of: 16_384), cancellationRequested() {
                    return nil
                }
                let leftSample = block.left[index]
                let rightSample = block.right[index]
                computedPeak = max(computedPeak, abs(leftSample), abs(rightSample))
                let leftSquare = Double(leftSample * leftSample)
                let rightSquare = Double(rightSample * rightSample)
                energy += leftSquare + rightSquare
                sum += Double(leftSample + rightSample)
                cross += Double(leftSample * rightSample)
                leftEnergy += leftSquare
                rightEnergy += rightSquare
                lowLeft += (Double(leftSample) - lowLeft) * lowPassCoefficient
                lowRight += (Double(rightSample) - lowRight) * lowPassCoefficient
                lowCross += lowLeft * lowRight
                lowLeftEnergy += lowLeft * lowLeft
                lowRightEnergy += lowRight * lowRight
                analyzed += 1
            }
        }
        peak = computedPeak
        guard let stereoTruePeak = BS1770AudioEvidence.stereoTruePeak(
            blocks: blocks,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        let computedTruePeak = max(stereoTruePeak.left, stereoTruePeak.right)
        truePeakEstimate = Float(computedTruePeak)
        truePeakDBTP = Float(
            BS1770AudioEvidence.decibelsTruePeak(amplitude: computedTruePeak)
        )
        rms = Float(sqrt(energy / Double(count * 2)))
        dcOffset = Float(sum / Double(count * 2))
        stereoCorrelation = Float(
            cross / sqrt(max(0.0000001, leftEnergy * rightEnergy))
        )
        lowStereoCorrelation = Float(
            lowCross / sqrt(max(0.0000001, lowLeftEnergy * lowRightEnergy))
        )
        maxBoundaryDelta = Self.maximumBoundaryDelta(
            leftBlocks: blocks.map(\.left),
            rightBlocks: blocks.map(\.right)
        )
        finite = computedFinite
        guard let computedHash = Self.hash(
            blocks: blocks,
            cancellationRequested: cancellationRequested
        ), let computedMusical = MusicalQualityMetrics(
            blocks: blocks,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        sampleHash = computedHash
        musical = computedMusical
        analysisPeakWorkingByteCount =
            computedMusical.perceptualEvidence.peakWorkingByteCount +
            computedMusical.loudnessPeakWorkingByteCount +
            2 * 12 * MemoryLayout<Double>.stride
        loudnessEstimate = Float(computedMusical.integratedLoudness)
    }

    package static func lowPassCoefficient(sampleRate: Double) -> Double {
        guard sampleRate.isFinite, sampleRate > 0 else { return 0 }
        return 1 - exp(
            -2 * Double.pi * lowStereoCorrelationCutoffHz / sampleRate
        )
    }

    package static func maximumBoundaryDelta(
        leftBlocks: [[Float]],
        rightBlocks: [[Float]]
    ) -> Float {
        let blockCount = min(leftBlocks.count, rightBlocks.count)
        guard blockCount > 1 else { return 0 }
        var result: Float = 0
        for index in 1..<blockCount {
            let leftDelta = abs(
                (leftBlocks[index].first ?? 0) -
                    (leftBlocks[index - 1].last ?? 0)
            )
            let rightDelta = abs(
                (rightBlocks[index].first ?? 0) -
                    (rightBlocks[index - 1].last ?? 0)
            )
            result = max(result, leftDelta, rightDelta)
        }
        return result
    }

    private static func hash(
        blocks: [RenderBlock],
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> String? {
        var hash: UInt64 = 0xcbf29ce484222325
        for channel in 0..<2 {
            for block in blocks {
                let samples = channel == 0 ? block.left : block.right
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
        return fixedWidthFingerprintHex(hash)
    }
}
