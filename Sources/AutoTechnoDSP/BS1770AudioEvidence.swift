import Foundation

/// Offline-only ITU-R BS.1770-5 programme-loudness evidence for the native
/// stereo route. Filtering, gating, and aggregation run over immutable,
/// app-owned PCM during preparation; none of this work enters the callback.
package struct BS1770LoudnessMeasurement: Equatable, Sendable {
    package static let standard = "ITU-R BS.1770-5"
    package static let silenceFloorLKFS = -120.0
    package static let absoluteGateLKFS = -70.0
    package static let relativeGateOffsetLU = -10.0

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

    package init?(
        left: [Float],
        right: [Float],
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) {
        guard !cancellationRequested() else { return nil }
        let count = min(left.count, right.count)
        guard count > 0, sampleRate.isFinite, sampleRate > 0 else {
            integratedLoudness = Self.silenceFloorLKFS
            maximumMomentaryLoudness = Self.silenceFloorLKFS
            maximumShortTermLoudness = Self.silenceFloorLKFS
            loudnessRange = 0
            momentaryBlockCount = 0
            absoluteGatedBlockCount = 0
            relativeGatedBlockCount = 0
            shortTermBlockCount = 0
            return
        }

        guard let energyPrefix = BS1770AudioEvidence.kWeightedStereoEnergyPrefix(
            left: left,
            right: right,
            count: count,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        guard energyPrefix.last?.isFinite == true else {
            integratedLoudness = .nan
            maximumMomentaryLoudness = .nan
            maximumShortTermLoudness = .nan
            loudnessRange = .nan
            momentaryBlockCount = 0
            absoluteGatedBlockCount = 0
            relativeGatedBlockCount = 0
            shortTermBlockCount = 0
            return
        }

        let momentaryEnergies = Self.blockEnergies(
            prefix: energyPrefix,
            frameCount: count,
            blockFrames: max(1, Int((sampleRate * 0.4).rounded())),
            hopFrames: max(1, Int((sampleRate * 0.1).rounded()))
        )
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
        integratedLoudness = Self.loudness(
            energy: Self.meanEnergy(relativeGated)
        )
        maximumMomentaryLoudness = momentaryLoudness.max() ??
            Self.silenceFloorLKFS
        momentaryBlockCount = momentaryEnergies.count
        absoluteGatedBlockCount = absoluteGated.count
        relativeGatedBlockCount = relativeGated.count

        let shortTermEnergies = Self.blockEnergies(
            prefix: energyPrefix,
            frameCount: count,
            blockFrames: max(1, Int((sampleRate * 3).rounded())),
            hopFrames: max(1, Int(sampleRate.rounded()))
        )
        let shortTerm = shortTermEnergies.map(Self.loudness(energy:))
        maximumShortTermLoudness = shortTerm.max() ?? integratedLoudness
        shortTermBlockCount = shortTerm.count
        let loudnessRangeGate = max(
            Self.absoluteGateLKFS,
            integratedLoudness - 20
        )
        let loudnessRangePopulation = shortTerm.filter {
            $0 > loudnessRangeGate
        }.sorted()
        loudnessRange = loudnessRangePopulation.count > 1
            ? Self.percentile(loudnessRangePopulation, 0.95) -
                Self.percentile(loudnessRangePopulation, 0.10)
            : 0
    }

    private static func blockEnergies(
        prefix: [Double],
        frameCount: Int,
        blockFrames: Int,
        hopFrames: Int
    ) -> [Double] {
        guard frameCount >= blockFrames else { return [] }
        var result: [Double] = []
        result.reserveCapacity(1 + (frameCount - blockFrames) / hopFrames)
        var start = 0
        while start + blockFrames <= frameCount {
            let end = start + blockFrames
            result.append((prefix[end] - prefix[start]) / Double(blockFrames))
            start += hopFrames
        }
        return result
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

    package static func decibelsTruePeak(amplitude: Double) -> Double {
        guard amplitude.isFinite else { return .nan }
        guard amplitude > 0 else { return -120 }
        return 20 * log10(amplitude)
    }

    private struct BiquadState {
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

    fileprivate static func kWeightedStereoEnergyPrefix(
        left: [Float],
        right: [Float],
        count: Int,
        sampleRate: Double,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> [Double]? {
        guard let coefficients = kWeightingCoefficients(sampleRate: sampleRate) else {
            return [Double](repeating: .nan, count: count + 1)
        }
        var leftShelf = BiquadState()
        var leftHighPass = BiquadState()
        var rightShelf = BiquadState()
        var rightHighPass = BiquadState()
        var prefix: [Double] = [0]
        prefix.reserveCapacity(count + 1)
        var accumulatedEnergy = 0.0
        for index in 0..<count {
            if index.isMultiple(of: 16_384), cancellationRequested() { return nil }
            let filteredLeft = leftHighPass.process(
                leftShelf.process(
                    Double(left[index]),
                    coefficients: coefficients.shelf
                ),
                coefficients: coefficients.highPass
            )
            let filteredRight = rightHighPass.process(
                rightShelf.process(
                    Double(right[index]),
                    coefficients: coefficients.shelf
                ),
                coefficients: coefficients.highPass
            )
            accumulatedEnergy += filteredLeft * filteredLeft +
                filteredRight * filteredRight
            prefix.append(accumulatedEnergy)
        }
        return prefix
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
