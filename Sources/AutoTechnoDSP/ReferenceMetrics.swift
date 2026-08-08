import Foundation

public struct ReferenceMetrics: Equatable, Sendable {
    public let peak: Float
    public let truePeakEstimate: Float
    public let rms: Float
    public let crestFactor: Float
    public let stereoCorrelation: Float
    public let boundaryStart: Float
    public let boundaryEnd: Float
    public let sampleHash: String

    public init(_ render: RenderedBar) {
        peak = render.peak
        truePeakEstimate = max(Self.cubicPeak(render.leftSamples), Self.cubicPeak(render.rightSamples))
        rms = render.rms
        crestFactor = render.crestFactor
        stereoCorrelation = render.stereoCorrelation
        boundaryStart = render.leftSamples.first ?? 0
        boundaryEnd = render.leftSamples.last ?? 0
        sampleHash = Self.hash(render.leftSamples, render.rightSamples)
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
                let t = Double(subdivision) / 4.0
                let value = 0.5 * ((2 * p1) + (-p0 + p2) * t +
                    (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                    (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
                result = max(result, abs(Float(value)))
            }
        }
        return result
    }

    public static func hash(_ channels: [Float]...) -> String {
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
