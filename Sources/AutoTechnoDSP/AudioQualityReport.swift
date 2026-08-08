import Foundation

package struct AudioQualityReport: Equatable, Sendable {
    package let peak: Float
    package let truePeakEstimate: Float
    package let rms: Float
    package let loudnessEstimate: Float
    package let dcOffset: Float
    package let stereoCorrelation: Float
    package let lowStereoCorrelation: Float
    package let maxBoundaryDelta: Float
    package let finite: Bool
    package let sampleHash: String
    package let musical: MusicalQualityMetrics

    package init(blocks: [RenderBlock], sampleRate: Double) {
        let left = blocks.flatMap(\.left)
        let right = blocks.flatMap(\.right)
        let count = min(left.count, right.count)
        guard count > 0 else {
            peak = 0
            truePeakEstimate = 0
            rms = 0
            loudnessEstimate = -120
            dcOffset = 0
            stereoCorrelation = 1
            lowStereoCorrelation = 1
            maxBoundaryDelta = 0
            finite = true
            sampleHash = "0000000000000000"
            musical = MusicalQualityMetrics(left: [], right: [], sampleRate: sampleRate)
            return
        }

        peak = zip(left.prefix(count), right.prefix(count)).reduce(0) {
            max($0, abs($1.0), abs($1.1))
        }
        truePeakEstimate = max(Self.cubicPeak(left), Self.cubicPeak(right))
        let energy = zip(left.prefix(count), right.prefix(count)).reduce(0.0) {
            $0 + Double($1.0 * $1.0) + Double($1.1 * $1.1)
        }
        rms = Float(sqrt(energy / Double(count * 2)))
        loudnessEstimate = Float(-0.691 + 20 * log10(max(Double(rms), 0.000000001)))
        let sum = zip(left.prefix(count), right.prefix(count)).reduce(0.0) {
            $0 + Double($1.0 + $1.1)
        }
        dcOffset = Float(sum / Double(count * 2))
        let cross = zip(left.prefix(count), right.prefix(count)).reduce(0.0) {
            $0 + Double($1.0 * $1.1)
        }
        let leftEnergy = left.prefix(count).reduce(0.0) { $0 + Double($1 * $1) }
        let rightEnergy = right.prefix(count).reduce(0.0) { $0 + Double($1 * $1) }
        stereoCorrelation = Float(cross / sqrt(max(0.0000001, leftEnergy * rightEnergy)))
        var lowLeft = 0.0
        var lowRight = 0.0
        var lowCross = 0.0
        var lowLeftEnergy = 0.0
        var lowRightEnergy = 0.0
        for pair in zip(left.prefix(count), right.prefix(count)) {
            lowLeft += (Double(pair.0) - lowLeft) * 0.018
            lowRight += (Double(pair.1) - lowRight) * 0.018
            lowCross += lowLeft * lowRight
            lowLeftEnergy += lowLeft * lowLeft
            lowRightEnergy += lowRight * lowRight
        }
        lowStereoCorrelation = Float(lowCross / sqrt(max(0.0000001, lowLeftEnergy * lowRightEnergy)))
        maxBoundaryDelta = blocks.dropFirst().enumerated().reduce(0) { result, pair in
            let previous = blocks[pair.offset].left.last ?? 0
            let next = pair.element.left.first ?? 0
            return max(result, abs(next - previous))
        }
        finite = left.allSatisfy(\.isFinite) && right.allSatisfy(\.isFinite)
        sampleHash = Self.hash(left, right)
        musical = MusicalQualityMetrics(left: left, right: right, sampleRate: sampleRate)
    }

    private static func cubicPeak(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return abs(samples.first ?? 0) }
        var result = samples.reduce(0) { max($0, abs($1)) }
        for index in 0..<(samples.count - 1) {
            let p0 = Double(samples[max(0, index - 1)])
            let p1 = Double(samples[index])
            let p2 = Double(samples[index + 1])
            let p3 = Double(samples[min(samples.count - 1, index + 2)])
            for subdivision in 1..<4 {
                let t = Double(subdivision) / 4
                let value = 0.5 * ((2 * p1) + (-p0 + p2) * t +
                    (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                    (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
                result = max(result, abs(Float(value)))
            }
        }
        return result
    }

    private static func hash(_ channels: [Float]...) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for channel in channels {
            for sample in channel {
                var bits = sample.bitPattern
                for _ in 0..<4 {
                    hash ^= UInt64(bits & 0xff)
                    hash &*= 0x100000001b3
                    bits >>= 8
                }
            }
        }
        return String(format: "%016llx", hash)
    }
}
