import Foundation

package enum PCMStereoCompatibilityState: String, Codable, Equatable, Sendable {
    /// Both channels contain exact digital zero in the analyzed domain.
    case inactive
    /// Active channels are sample-identical, so arithmetic mono preserves them.
    case safeExactMono
    /// Active channels are exact opposites, so arithmetic mono cancels them.
    case unsafeExactCancellation
    /// Exactly one source channel is active; correlation is undefined.
    case oneSided
    /// Active stereo that is neither exact mono nor exact cancellation.
    case mixed
}

package struct PCMStereoDomainEvidence: Codable, Equatable, Sendable {
    package let name: String
    package let frameCount: Int
    package let leftMeanSquare: Double
    package let rightMeanSquare: Double
    package let stereoMeanSquare: Double
    package let crossMean: Double
    package let midMeanSquare: Double
    package let sideMeanSquare: Double
    package let correlation: Double?
    package let monoRetentionRatio: Double?
    package let monoLevelChangeDB: Double?
    package let sideEnergyShare: Double?
    package let sideToMidRatio: Double?
    package let state: PCMStereoCompatibilityState
    package let finite: Bool

    private enum CodingKeys: String, CodingKey {
        case name
        case frameCount
        case leftMeanSquare
        case rightMeanSquare
        case stereoMeanSquare
        case crossMean
        case midMeanSquare
        case sideMeanSquare
        case correlation
        case monoRetentionRatio
        case monoLevelChangeDB
        case sideEnergyShare
        case sideToMidRatio
        case state
        case finite
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(frameCount, forKey: .frameCount)
        try container.encode(leftMeanSquare, forKey: .leftMeanSquare)
        try container.encode(rightMeanSquare, forKey: .rightMeanSquare)
        try container.encode(stereoMeanSquare, forKey: .stereoMeanSquare)
        try container.encode(crossMean, forKey: .crossMean)
        try container.encode(midMeanSquare, forKey: .midMeanSquare)
        try container.encode(sideMeanSquare, forKey: .sideMeanSquare)
        try encode(correlation, forKey: .correlation, into: &container)
        try encode(
            monoRetentionRatio,
            forKey: .monoRetentionRatio,
            into: &container
        )
        try encode(
            monoLevelChangeDB,
            forKey: .monoLevelChangeDB,
            into: &container
        )
        try encode(sideEnergyShare, forKey: .sideEnergyShare, into: &container)
        try encode(sideToMidRatio, forKey: .sideToMidRatio, into: &container)
        try container.encode(state, forKey: .state)
        try container.encode(finite, forKey: .finite)
    }

    private func encode(
        _ value: Double?,
        forKey key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }
}

package struct PCMStereoCompatibilitySegment: Codable, Equatable, Sendable {
    package let startFrame: Int
    package let frameCount: Int
    package let domains: [PCMStereoDomainEvidence]
}

package struct PCMStereoCompatibilityEvidence: Codable, Equatable, Sendable {
    package let schema: String
    package let sampleRate: Int
    package let sourceChannelCount: Int
    package let frameCount: Int
    package let segmentFrameCount: Int
    package let domains: [String]
    package let summary: [PCMStereoDomainEvidence]
    package let segments: [PCMStereoCompatibilitySegment]
}

/// Detached stereo translation evidence for exact local corpus PCM. The
/// classification is intentionally structural: only sample-identical stereo
/// is guaranteed safe and only exact opposite-polarity stereo is guaranteed
/// unsafe. Mixed width and decorrelation remain descriptive, not ranked.
package enum PCMStereoCompatibilityAnalyzer {
    package static let schema = "autotechno-pcm-stereo-compatibility.v1"
    package static let analyzerVersion =
        "autotechno-pcm-stereo-compatibility-analyzer.v1"
    package static let domainNames = ["full", "sub", "low-mid", "mid", "high"]
    package static let midSideScaling = "half-sum-half-difference"
    package static let monoFold = "arithmetic-mean-of-two-source-channels"
    package static let correlationDenominator =
        "exact-identities-else-sqrt-left-energy-times-sqrt-right-energy"
    package static let compatibilityClassification =
        "exact-digital-identities-only-mixed-unranked"
    package static let bandEnergyModel =
        "causal-one-pole-difference-non-power-complementary"
    package static let bandFilterReset = "reset-at-each-segment-boundary"
    package static let aggregation = "frame-weighted-raw-energy-sums"
    package static let decibelFloor = -120.0

    private struct Accumulator {
        var frameCount = 0
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        var crossEnergy = 0.0
        var midEnergy = 0.0
        var sideEnergy = 0.0

        mutating func add(left: Double, right: Double) {
            let mid = (left + right) * 0.5
            let side = (left - right) * 0.5
            frameCount += 1
            leftEnergy += left * left
            rightEnergy += right * right
            crossEnergy += left * right
            midEnergy += mid * mid
            sideEnergy += side * side
        }

        mutating func merge(_ other: Accumulator) {
            frameCount += other.frameCount
            leftEnergy += other.leftEnergy
            rightEnergy += other.rightEnergy
            crossEnergy += other.crossEnergy
            midEnergy += other.midEnergy
            sideEnergy += other.sideEnergy
        }
    }

    package static func analyze(
        channels: [[Float]],
        sampleRate: Double,
        segmentFrameCount: Int
    ) -> PCMStereoCompatibilityEvidence? {
        guard sampleRate.isFinite, sampleRate > 0,
              sampleRate.rounded() == sampleRate,
              sampleRate <= Double(Int.max),
              (channels.count == 1 || channels.count == 2),
              let frameCount = channels.first?.count,
              frameCount > 0,
              channels.allSatisfy({ $0.count == frameCount }),
              channels.allSatisfy({ $0.allSatisfy(\.isFinite) }),
              segmentFrameCount > 0,
              segmentFrameCount <= SpectrumMaskingAnalyzer.maximumFrames else {
            return nil
        }

        let leftChannel = channels[0]
        let rightChannel = channels.count == 2 ? channels[1] : leftChannel
        var summaryAccumulators = [Accumulator](
            repeating: Accumulator(),
            count: domainNames.count
        )
        var segments: [PCMStereoCompatibilitySegment] = []
        segments.reserveCapacity(
            (frameCount + segmentFrameCount - 1) / segmentFrameCount
        )
        var startFrame = 0
        while startFrame < frameCount {
            let count = min(segmentFrameCount, frameCount - startFrame)
            guard var leftFilter = MaskingBandFilter(sampleRate: sampleRate),
                  var rightFilter = MaskingBandFilter(sampleRate: sampleRate) else {
                return nil
            }
            var accumulators = [Accumulator](
                repeating: Accumulator(),
                count: domainNames.count
            )
            for offset in 0..<count {
                let left = Double(leftChannel[startFrame + offset])
                let right = Double(rightChannel[startFrame + offset])
                accumulators[0].add(left: left, right: right)
                guard let leftBands = leftFilter.process(left),
                      let rightBands = rightFilter.process(right) else {
                    return nil
                }
                for band in SpectrumMaskingAnalyzer.bands.indices {
                    accumulators[band + 1].add(
                        left: leftBands[band],
                        right: rightBands[band]
                    )
                }
            }
            for index in summaryAccumulators.indices {
                summaryAccumulators[index].merge(accumulators[index])
            }
            let domains = zip(domainNames, accumulators).map(makeEvidence)
            guard domains.allSatisfy(\.finite) else { return nil }
            segments.append(PCMStereoCompatibilitySegment(
                startFrame: startFrame,
                frameCount: count,
                domains: domains
            ))
            startFrame += count
        }
        let summary = zip(domainNames, summaryAccumulators).map(makeEvidence)
        guard summary.allSatisfy(\.finite) else { return nil }
        return PCMStereoCompatibilityEvidence(
            schema: schema,
            sampleRate: Int(sampleRate),
            sourceChannelCount: channels.count,
            frameCount: frameCount,
            segmentFrameCount: segmentFrameCount,
            domains: domainNames,
            summary: summary,
            segments: segments
        )
    }

    private static func makeEvidence(
        _ element: (String, Accumulator)
    ) -> PCMStereoDomainEvidence {
        let (name, accumulator) = element
        let divisor = Double(max(1, accumulator.frameCount))
        let left = accumulator.leftEnergy / divisor
        let right = accumulator.rightEnergy / divisor
        let stereo = (left + right) * 0.5
        let cross = accumulator.crossEnergy / divisor
        let mid = accumulator.midEnergy / divisor
        let side = accumulator.sideEnergy / divisor
        let state: PCMStereoCompatibilityState
        if left == 0 && right == 0 {
            state = .inactive
        } else if left == 0 || right == 0 {
            state = .oneSided
        } else if side == 0 {
            state = .safeExactMono
        } else if mid == 0 {
            state = .unsafeExactCancellation
        } else {
            state = .mixed
        }
        let correlation: Double?
        if left == 0 || right == 0 {
            correlation = nil
        } else if state == .safeExactMono {
            correlation = 1
        } else if state == .unsafeExactCancellation {
            correlation = -1
        } else {
            correlation = max(
                -1,
                min(1, cross / (sqrt(left) * sqrt(right)))
            )
        }
        let monoRetention = stereo > 0 ? mid / stereo : nil
        let monoLevelChange = monoRetention.map {
            $0 > 0 ? max(decibelFloor, 10 * log10($0)) : decibelFloor
        }
        let midSideTotal = mid + side
        let sideShare = midSideTotal > 0 ? side / midSideTotal : nil
        let unboundedSideToMid = mid > 0 ? side / mid : nil
        let sideToMid = unboundedSideToMid?.isFinite == true
            ? unboundedSideToMid : nil
        let required = [left, right, stereo, cross, mid, side]
        let optional = [correlation, monoRetention, monoLevelChange, sideShare, sideToMid]
            .compactMap { $0 }
        return PCMStereoDomainEvidence(
            name: name,
            frameCount: accumulator.frameCount,
            leftMeanSquare: left,
            rightMeanSquare: right,
            stereoMeanSquare: stereo,
            crossMean: cross,
            midMeanSquare: mid,
            sideMeanSquare: side,
            correlation: correlation,
            monoRetentionRatio: monoRetention,
            monoLevelChangeDB: monoLevelChange,
            sideEnergyShare: sideShare,
            sideToMidRatio: sideToMid,
            state: state,
            finite: required.allSatisfy(\.isFinite) &&
                optional.allSatisfy(\.isFinite)
        )
    }
}
