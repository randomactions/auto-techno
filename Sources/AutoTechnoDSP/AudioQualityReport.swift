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
        var left: [Float] = []
        var right: [Float] = []
        left.reserveCapacity(blocks.reduce(0) { $0 + $1.left.count })
        right.reserveCapacity(blocks.reduce(0) { $0 + $1.right.count })
        for block in blocks {
            guard !cancellationRequested() else { return nil }
            left.append(contentsOf: block.left)
            right.append(contentsOf: block.right)
        }
        guard let leftFinite = Self.samplesAreFinite(
            left,
            cancellationRequested: cancellationRequested
        ), let rightFinite = Self.samplesAreFinite(
            right,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        let computedFinite = leftFinite && rightFinite
        let count = min(left.count, right.count)
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
            return
        }
        analyzedFrameCount = count

        var computedPeak: Float = 0
        var energy = 0.0
        var sum = 0.0
        var cross = 0.0
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        for index in 0..<count {
            if index.isMultiple(of: 16_384), cancellationRequested() { return nil }
            let leftSample = left[index]
            let rightSample = right[index]
            computedPeak = max(computedPeak, abs(leftSample), abs(rightSample))
            let leftSquare = Double(leftSample * leftSample)
            let rightSquare = Double(rightSample * rightSample)
            energy += leftSquare + rightSquare
            sum += Double(leftSample + rightSample)
            cross += Double(leftSample * rightSample)
            leftEnergy += leftSquare
            rightEnergy += rightSquare
        }
        peak = computedPeak
        guard let leftTruePeak = BS1770AudioEvidence.truePeak(
            left,
            cancellationRequested: cancellationRequested
        ), let rightTruePeak = BS1770AudioEvidence.truePeak(
            right,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        let computedTruePeak = max(leftTruePeak, rightTruePeak)
        truePeakEstimate = Float(computedTruePeak)
        truePeakDBTP = Float(
            BS1770AudioEvidence.decibelsTruePeak(amplitude: computedTruePeak)
        )
        rms = Float(sqrt(energy / Double(count * 2)))
        dcOffset = Float(sum / Double(count * 2))
        stereoCorrelation = Float(
            cross / sqrt(max(0.0000001, leftEnergy * rightEnergy))
        )
        var lowLeft = 0.0
        var lowRight = 0.0
        var lowCross = 0.0
        var lowLeftEnergy = 0.0
        var lowRightEnergy = 0.0
        let lowPassCoefficient = Self.lowPassCoefficient(sampleRate: sampleRate)
        for index in 0..<count {
            if index.isMultiple(of: 16_384), cancellationRequested() { return nil }
            lowLeft += (Double(left[index]) - lowLeft) * lowPassCoefficient
            lowRight += (Double(right[index]) - lowRight) * lowPassCoefficient
            lowCross += lowLeft * lowRight
            lowLeftEnergy += lowLeft * lowLeft
            lowRightEnergy += lowRight * lowRight
        }
        lowStereoCorrelation = Float(
            lowCross / sqrt(max(0.0000001, lowLeftEnergy * lowRightEnergy))
        )
        maxBoundaryDelta = Self.maximumBoundaryDelta(
            leftBlocks: blocks.map(\.left),
            rightBlocks: blocks.map(\.right)
        )
        finite = computedFinite
        guard let computedHash = Self.hash(
            [left, right],
            cancellationRequested: cancellationRequested
        ), let computedMusical = MusicalQualityMetrics(
            left: left,
            right: right,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        sampleHash = computedHash
        musical = computedMusical
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

    private static func samplesAreFinite(
        _ samples: [Float],
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> Bool? {
        var result = true
        for index in samples.indices {
            if index.isMultiple(of: 16_384), cancellationRequested() { return nil }
            result = result && samples[index].isFinite
        }
        return result
    }

    private static func hash(
        _ channels: [[Float]],
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> String? {
        var hash: UInt64 = 0xcbf29ce484222325
        for channel in channels {
            for (index, sample) in channel.enumerated() {
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
        return fixedWidthFingerprintHex(hash)
    }
}
