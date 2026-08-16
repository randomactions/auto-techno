import Foundation

/// Offline-only ITU-R BS.1770-5 programme-loudness evidence for the native
/// stereo route. Filtering, gating, and aggregation run over immutable,
/// app-owned PCM during preparation; none of this work enters the callback.
package struct BS1770LoudnessMeasurement: Equatable, Sendable {
    package static let standard = "ITU-R BS.1770-5"
    package static let silenceFloorLKFS = -120.0
    package static let absoluteGateLKFS = -70.0
    package static let relativeGateOffsetLU = -10.0
    /// A 16-bar phrase at the fixed 130 BPM lasts 29.54 seconds. The rounded
    /// 32-second envelope leaves route-rounding headroom without allowing an
    /// unbounded programme-energy collection.
    package static let maximumProgrammeSeconds = 32.0
    package static let maximumMomentaryBlockCount = 320
    package static let maximumShortTermBlockCount = 32
    private static let boundedAggregationScratchScalarCount =
        maximumMomentaryBlockCount * 4 + maximumShortTermBlockCount * 3

    package let integratedLoudness: Double
    package let maximumMomentaryLoudness: Double
    package let maximumShortTermLoudness: Double
    /// Descriptive EBU-style short-term spread. This is retained as evidence,
    /// not used as a shipping policy threshold.
    package let loudnessRange: Double
    package let momentaryBlockCount: Int
    package let absoluteGatedBlockCount: Int
    package let relativeGatedBlockCount: Int
    package let shortTermBlockCount: Int
    package let maximumBufferedFrameCount: Int
    package let peakWorkingByteCount: Int

    package init(left: [Float], right: [Float], sampleRate: Double) {
        guard let measurement = Self(
            left: left,
            right: right,
            sampleRate: sampleRate,
            cancellationRequested: { false }
        ) else {
            preconditionFailure("Non-cancellable BS.1770 measurement stopped unexpectedly")
        }
        self = measurement
    }

    package init?<Left, Right>(
        left: Left,
        right: Right,
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) where
        Left: RandomAccessCollection,
        Right: RandomAccessCollection,
        Left.Element == Float,
        Right.Element == Float,
        Left.Index == Int,
        Right.Index == Int {
        guard left.startIndex == 0, right.startIndex == 0 else { return nil }
        guard let result = Self.streamingMeasurement(
            chunks: [(left, right)],
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        self = result
    }

    package init?(
        blocks: [RenderBlock],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) {
        guard let result = Self.streamingMeasurement(
            chunks: blocks.map { ($0.left, $0.right) },
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        self = result
    }

    package init?(
        leftChunks: [[Float]],
        rightChunks: [[Float]],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) {
        guard leftChunks.count == rightChunks.count,
              let result = Self.streamingMeasurement(
                  chunks: zip(leftChunks, rightChunks).map { ($0, $1) },
                  sampleRate: sampleRate,
                  cancellationRequested: cancellationRequested
              ) else { return nil }
        self = result
    }

    private init(
        integratedLoudness: Double,
        maximumMomentaryLoudness: Double,
        maximumShortTermLoudness: Double,
        loudnessRange: Double,
        momentaryBlockCount: Int,
        absoluteGatedBlockCount: Int,
        relativeGatedBlockCount: Int,
        shortTermBlockCount: Int,
        maximumBufferedFrameCount: Int,
        peakWorkingByteCount: Int
    ) {
        self.integratedLoudness = integratedLoudness
        self.maximumMomentaryLoudness = maximumMomentaryLoudness
        self.maximumShortTermLoudness = maximumShortTermLoudness
        self.loudnessRange = loudnessRange
        self.momentaryBlockCount = momentaryBlockCount
        self.absoluteGatedBlockCount = absoluteGatedBlockCount
        self.relativeGatedBlockCount = relativeGatedBlockCount
        self.shortTermBlockCount = shortTermBlockCount
        self.maximumBufferedFrameCount = maximumBufferedFrameCount
        self.peakWorkingByteCount = peakWorkingByteCount
    }

    private static func streamingMeasurement<Left, Right>(
        chunks: [(Left, Right)],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> BS1770LoudnessMeasurement? where
        Left: RandomAccessCollection,
        Right: RandomAccessCollection,
        Left.Element == Float,
        Right.Element == Float,
        Left.Index == Int,
        Right.Index == Int {
        guard !cancellationRequested() else { return nil }
        let sourceFrameCount = chunks.reduce(0) {
            $0 + min($1.0.count, $1.1.count)
        }
        guard sourceFrameCount > 0, sampleRate.isFinite, sampleRate > 0 else {
            return BS1770LoudnessMeasurement(
                integratedLoudness: silenceFloorLKFS,
                maximumMomentaryLoudness: silenceFloorLKFS,
                maximumShortTermLoudness: silenceFloorLKFS,
                loudnessRange: 0,
                momentaryBlockCount: 0,
                absoluteGatedBlockCount: 0,
                relativeGatedBlockCount: 0,
                shortTermBlockCount: 0,
                maximumBufferedFrameCount: 0,
                peakWorkingByteCount: 0
            )
        }
        guard let coefficients = BS1770AudioEvidence.kWeightingCoefficients(
            sampleRate: sampleRate
        ) else {
            return BS1770LoudnessMeasurement(
                integratedLoudness: .nan,
                maximumMomentaryLoudness: .nan,
                maximumShortTermLoudness: .nan,
                loudnessRange: .nan,
                momentaryBlockCount: 0,
                absoluteGatedBlockCount: 0,
                relativeGatedBlockCount: 0,
                shortTermBlockCount: 0,
                maximumBufferedFrameCount: 0,
                peakWorkingByteCount: 0
            )
        }
        var leftShelf = StreamingBiquadState()
        var leftHighPass = StreamingBiquadState()
        var rightShelf = StreamingBiquadState()
        var rightHighPass = StreamingBiquadState()
        var momentary = RollingEnergyWindow(
            blockFrames: max(1, Int((sampleRate * 0.4).rounded())),
            hopFrames: max(1, Int((sampleRate * 0.1).rounded())),
            maximumEmissionCount: maximumMomentaryBlockCount
        )
        var shortTerm = RollingEnergyWindow(
            blockFrames: max(1, Int((sampleRate * 3).rounded())),
            hopFrames: max(1, Int(sampleRate.rounded())),
            maximumEmissionCount: maximumShortTermBlockCount
        )
        let maximumBufferedFrameCount = momentary.blockFrames +
            shortTerm.blockFrames
        let peakWorkingByteCount = (
            maximumBufferedFrameCount + boundedAggregationScratchScalarCount
        ) * MemoryLayout<Double>.stride
        var consumed = 0
        var finite = true
        for (left, right) in chunks {
            let count = min(left.count, right.count)
            for index in 0..<count {
                if consumed.isMultiple(of: 16_384), cancellationRequested() {
                    return nil
                }
                let leftSample = Double(left[index])
                let rightSample = Double(right[index])
                finite = finite && leftSample.isFinite && rightSample.isFinite
                let filteredLeft = leftHighPass.process(
                    leftShelf.process(
                        leftSample,
                        coefficients: coefficients.shelf
                    ),
                    coefficients: coefficients.highPass
                )
                let filteredRight = rightHighPass.process(
                    rightShelf.process(
                        rightSample,
                        coefficients: coefficients.shelf
                    ),
                    coefficients: coefficients.highPass
                )
                let energy = filteredLeft * filteredLeft +
                    filteredRight * filteredRight
                momentary.consume(energy)
                shortTerm.consume(energy)
                consumed += 1
            }
        }
        let momentaryEnergies = momentary.values
        let shortTermEnergies = shortTerm.values
        guard finite, !momentary.overflowed, !shortTerm.overflowed,
              momentaryEnergies.allSatisfy(\.isFinite),
              shortTermEnergies.allSatisfy(\.isFinite) else {
            return BS1770LoudnessMeasurement(
                integratedLoudness: .nan,
                maximumMomentaryLoudness: .nan,
                maximumShortTermLoudness: .nan,
                loudnessRange: .nan,
                momentaryBlockCount: 0,
                absoluteGatedBlockCount: 0,
                relativeGatedBlockCount: 0,
                shortTermBlockCount: 0,
                maximumBufferedFrameCount: maximumBufferedFrameCount,
                peakWorkingByteCount: peakWorkingByteCount
            )
        }

        let momentaryLoudness = momentaryEnergies.map(Self.loudness(energy:))
        let absoluteGated = momentaryEnergies.filter {
            Self.loudness(energy: $0) > Self.absoluteGateLKFS
        }
        let absoluteLoudness = Self.loudness(
            energy: Self.meanEnergy(absoluteGated)
        )
        let relativeGate = absoluteLoudness + Self.relativeGateOffsetLU
        let relativeGated = absoluteGated.filter {
            let value = Self.loudness(energy: $0)
            return value > Self.absoluteGateLKFS && value > relativeGate
        }
        let integratedLoudness = Self.loudness(
            energy: Self.meanEnergy(relativeGated)
        )
        let maximumMomentaryLoudness = momentaryLoudness.max() ??
            Self.silenceFloorLKFS
        let shortTermLoudness = shortTermEnergies.map(Self.loudness(energy:))
        let maximumShortTermLoudness = shortTermLoudness.max() ?? integratedLoudness
        let loudnessRangeGate = max(
            Self.absoluteGateLKFS,
            integratedLoudness - 20
        )
        let loudnessRangePopulation = shortTermLoudness.filter {
            $0 > loudnessRangeGate
        }.sorted()
        let loudnessRange = loudnessRangePopulation.count > 1
            ? Self.percentile(loudnessRangePopulation, 0.95) -
                Self.percentile(loudnessRangePopulation, 0.10)
            : 0
        return BS1770LoudnessMeasurement(
            integratedLoudness: integratedLoudness,
            maximumMomentaryLoudness: maximumMomentaryLoudness,
            maximumShortTermLoudness: maximumShortTermLoudness,
            loudnessRange: loudnessRange,
            momentaryBlockCount: momentaryEnergies.count,
            absoluteGatedBlockCount: absoluteGated.count,
            relativeGatedBlockCount: relativeGated.count,
            shortTermBlockCount: shortTermLoudness.count,
            maximumBufferedFrameCount: maximumBufferedFrameCount,
            peakWorkingByteCount: peakWorkingByteCount
        )
    }

    private struct StreamingBiquadState {
        var z1 = 0.0
        var z2 = 0.0

        mutating func process(
            _ sample: Double,
            coefficients: BS1770BiquadCoefficients
        ) -> Double {
            let output = coefficients.b0 * sample + z1
            z1 = coefficients.b1 * sample - coefficients.a1 * output + z2
            z2 = coefficients.b2 * sample - coefficients.a2 * output
            return output
        }
    }

    private struct RollingEnergyWindow {
        let blockFrames: Int
        let hopFrames: Int
        let maximumEmissionCount: Int
        var ring: [Double]
        var writeIndex = 0
        var consumedFrameCount = 0
        var rollingSum = 0.0
        var emittedEnergies: [Double]
        var emittedCount = 0
        var overflowed = false

        init(blockFrames: Int, hopFrames: Int, maximumEmissionCount: Int) {
            self.blockFrames = blockFrames
            self.hopFrames = hopFrames
            self.maximumEmissionCount = maximumEmissionCount
            ring = [Double](repeating: 0, count: blockFrames)
            emittedEnergies = [Double](
                repeating: 0,
                count: maximumEmissionCount
            )
        }

        mutating func consume(_ energy: Double) {
            if consumedFrameCount >= blockFrames {
                rollingSum -= ring[writeIndex]
            }
            ring[writeIndex] = energy
            rollingSum += energy
            writeIndex = (writeIndex + 1) % blockFrames
            consumedFrameCount += 1
            if consumedFrameCount >= blockFrames,
               (consumedFrameCount - blockFrames).isMultiple(of: hopFrames) {
                if emittedCount < maximumEmissionCount {
                    emittedEnergies[emittedCount] =
                        rollingSum / Double(blockFrames)
                    emittedCount += 1
                } else {
                    overflowed = true
                }
            }
        }

        var values: [Double] {
            Array(emittedEnergies.prefix(emittedCount))
        }
    }

    private static func loudness(energy: Double) -> Double {
        guard energy.isFinite else { return .nan }
        guard energy > 0 else { return silenceFloorLKFS }
        return max(silenceFloorLKFS, -0.691 + 10 * log10(energy))
    }

    private static func meanEnergy(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func percentile(_ sorted: [Double], _ percentile: Double) -> Double {
        let position = Double(sorted.count - 1) * percentile
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        guard lower != upper else { return sorted[lower] }
        let fraction = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }
}

package struct BS1770BiquadCoefficients: Equatable, Sendable {
    package let b0: Double
    package let b1: Double
    package let b2: Double
    package let a1: Double
    package let a2: Double
}

/// Reference algorithms and coefficients from ITU-R BS.1770-5 Annexes 1 and
/// 2. The Annex 2 48th-order, four-phase FIR is deliberately used directly so
/// inter-sample peaks are evidence rather than cubic-interpolation guesses.
package enum BS1770AudioEvidence {
    package static let truePeakStandard = "ITU-R BS.1770-5 Annex 2"
    package static let truePeakOversamplingFactor = 4

    package static func kWeightingCoefficients(sampleRate: Double)
        -> (shelf: BS1770BiquadCoefficients, highPass: BS1770BiquadCoefficients)? {
        guard sampleRate.isFinite, sampleRate > 3_400 else { return nil }

        // Parameters are the bilinear-transform equivalents that reproduce
        // the Recommendation's published 48 kHz coefficient tables exactly.
        let shelfFrequency = 1_681.974_450_955_533
        let shelfGainDB = 3.999_843_853_973_347
        let shelfQ = 0.707_175_236_955_419_6
        let shelfK = tan(Double.pi * shelfFrequency / sampleRate)
        let shelfHighGain = pow(10, shelfGainDB / 20)
        let shelfBandGain = pow(shelfHighGain, 0.499_666_774_154_541_6)
        let shelfA0 = 1 + shelfK / shelfQ + shelfK * shelfK
        let shelf = BS1770BiquadCoefficients(
            b0: (shelfHighGain + shelfBandGain * shelfK / shelfQ +
                shelfK * shelfK) / shelfA0,
            b1: 2 * (shelfK * shelfK - shelfHighGain) / shelfA0,
            b2: (shelfHighGain - shelfBandGain * shelfK / shelfQ +
                shelfK * shelfK) / shelfA0,
            a1: 2 * (shelfK * shelfK - 1) / shelfA0,
            a2: (1 - shelfK / shelfQ + shelfK * shelfK) / shelfA0
        )

        let highPassFrequency = 38.135_470_876_024_44
        let highPassQ = 0.500_327_037_323_877_3
        let highPassK = tan(Double.pi * highPassFrequency / sampleRate)
        let highPassA0 = 1 + highPassK / highPassQ +
            highPassK * highPassK
        let highPass = BS1770BiquadCoefficients(
            b0: 1,
            b1: -2,
            b2: 1,
            a1: 2 * (highPassK * highPassK - 1) / highPassA0,
            a2: (1 - highPassK / highPassQ + highPassK * highPassK) /
                highPassA0
        )
        return (shelf, highPass)
    }

    package static func truePeak(
        _ samples: [Float],
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> Double? {
        guard !cancellationRequested() else { return nil }
        guard !samples.isEmpty else { return 0 }
        var samplePeak = 0.0
        for (index, sample) in samples.enumerated() {
            if index.isMultiple(of: 16_384), cancellationRequested() { return nil }
            guard sample.isFinite else { return .nan }
            samplePeak = max(samplePeak, abs(Double(sample)))
        }

        var filteredPeak = 0.0
        let tapCount = annex2PolyphaseCoefficients[0].count
        for outputIndex in 0..<(samples.count + tapCount - 1) {
            if outputIndex.isMultiple(of: 4_096), cancellationRequested() {
                return nil
            }
            for phase in annex2PolyphaseCoefficients.indices {
                var value = 0.0
                for tap in 0..<tapCount {
                    let inputIndex = outputIndex - tap
                    guard samples.indices.contains(inputIndex) else { continue }
                    value += annex2PolyphaseCoefficients[phase][tap] *
                        Double(samples[inputIndex])
                }
                filteredPeak = max(filteredPeak, abs(value))
            }
        }
        // Sample peak remains an explicit conservative lower bound at signal
        // edges where the finite FIR necessarily sees zero padding.
        return max(samplePeak, filteredPeak)
    }

    /// Fixed-memory stereo Annex 2 analysis over immutable render blocks. The
    /// 12-sample FIR history is preserved across block boundaries, so results
    /// are independent of render chunking and no phrase-sized channel copy is
    /// required.
    package static func stereoTruePeak(
        blocks: [RenderBlock],
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> (left: Double, right: Double)? {
        stereoTruePeak(
            leftChunks: blocks.map(\.left),
            rightChunks: blocks.map(\.right),
            cancellationRequested: cancellationRequested
        )
    }

    package static func stereoTruePeak<Left, Right>(
        left: Left,
        right: Right,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> (left: Double, right: Double)? where
        Left: RandomAccessCollection,
        Right: RandomAccessCollection,
        Left.Element == Float,
        Right.Element == Float,
        Left.Index == Int,
        Right.Index == Int {
        guard !cancellationRequested(),
              left.startIndex == 0,
              right.startIndex == 0,
              left.count == right.count else {
            return nil
        }
        var leftAccumulator = StreamingTruePeakAccumulator()
        var rightAccumulator = StreamingTruePeakAccumulator()
        for index in left.indices {
            if index.isMultiple(of: 4_096), cancellationRequested() {
                return nil
            }
            leftAccumulator.consume(Double(left[index]))
            rightAccumulator.consume(Double(right[index]))
        }
        leftAccumulator.flush()
        rightAccumulator.flush()
        return (leftAccumulator.peak, rightAccumulator.peak)
    }

    package static func stereoTruePeak(
        leftChunks: [[Float]],
        rightChunks: [[Float]],
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> (left: Double, right: Double)? {
        guard !cancellationRequested() else { return nil }
        guard leftChunks.count == rightChunks.count else {
            return (.nan, .nan)
        }
        var leftAccumulator = StreamingTruePeakAccumulator()
        var rightAccumulator = StreamingTruePeakAccumulator()
        var consumed = 0
        for (left, right) in zip(leftChunks, rightChunks) {
            let count = min(left.count, right.count)
            for index in 0..<count {
                if consumed.isMultiple(of: 4_096), cancellationRequested() {
                    return nil
                }
                leftAccumulator.consume(Double(left[index]))
                rightAccumulator.consume(Double(right[index]))
                consumed += 1
            }
        }
        leftAccumulator.flush()
        rightAccumulator.flush()
        return (leftAccumulator.peak, rightAccumulator.peak)
    }

    package static func decibelsTruePeak(amplitude: Double) -> Double {
        guard amplitude.isFinite else { return .nan }
        guard amplitude > 0 else { return -120 }
        return 20 * log10(amplitude)
    }

    private struct StreamingTruePeakAccumulator {
        private let tapCount = annex2PolyphaseCoefficients[0].count
        private var history = [Double](
            repeating: 0,
            count: annex2PolyphaseCoefficients[0].count
        )
        private var writeIndex = 0
        private var samplePeak = 0.0
        private var filteredPeak = 0.0
        private var finite = true

        mutating func consume(_ sample: Double) {
            guard sample.isFinite else {
                finite = false
                return
            }
            samplePeak = max(samplePeak, abs(sample))
            convolve(sample)
        }

        mutating func flush() {
            guard finite else { return }
            for _ in 0..<(tapCount - 1) { convolve(0) }
        }

        var peak: Double {
            finite ? max(samplePeak, filteredPeak) : .nan
        }

        private mutating func convolve(_ sample: Double) {
            history[writeIndex] = sample
            let newest = writeIndex
            writeIndex = (writeIndex + 1) % tapCount
            for phase in annex2PolyphaseCoefficients.indices {
                var value = 0.0
                for tap in 0..<tapCount {
                    let historyIndex = (newest - tap + tapCount) % tapCount
                    value += annex2PolyphaseCoefficients[phase][tap] *
                        history[historyIndex]
                }
                filteredPeak = max(filteredPeak, abs(value))
            }
        }
    }

    /// Columns from the Recommendation's order-48, four-phase FIR table.
    private static let annex2PolyphaseCoefficients: [[Double]] = [
        [
            0.0017089843750, 0.0109863281250, -0.0196533203125,
            0.0332031250000, -0.0594482421875, 0.1373291015625,
            0.9721679687500, -0.1022949218750, 0.0476074218750,
            -0.0266113281250, 0.0148925781250, -0.0083007812500,
        ],
        [
            -0.0291748046875, 0.0292968750000, -0.0517578125000,
            0.0891113281250, -0.1665039062500, 0.4650878906250,
            0.7797851562500, -0.2003173828125, 0.1015625000000,
            -0.0582275390625, 0.0330810546875, -0.0189208984375,
        ],
        [
            -0.0189208984375, 0.0330810546875, -0.0582275390625,
            0.1015625000000, -0.2003173828125, 0.7797851562500,
            0.4650878906250, -0.1665039062500, 0.0891113281250,
            -0.0517578125000, 0.0292968750000, -0.0291748046875,
        ],
        [
            -0.0083007812500, 0.0148925781250, -0.0266113281250,
            0.0476074218750, -0.1022949218750, 0.9721679687500,
            0.1373291015625, -0.0594482421875, 0.0332031250000,
            -0.0196533203125, 0.0109863281250, 0.0017089843750,
        ],
    ]
}
