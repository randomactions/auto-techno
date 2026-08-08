import Foundation

/// Read-only display envelope on a fixed decibel scale. Unlike per-bar peak
/// normalization, the same acoustic energy always produces the same height.
package enum WaveformEnvelope {
    package static func fixedDB(left: [Float], right: [Float], buckets: Int = 64,
                                floorDB: Double = -48, ceilingDB: Double = -6) -> [Float] {
        let sampleCount = min(left.count, right.count)
        guard sampleCount > 0, buckets > 0, ceilingDB > floorDB else { return [] }
        let bucketSize = max(1, sampleCount / buckets)
        var envelope: [Float] = []
        envelope.reserveCapacity(buckets)

        for bucket in 0..<buckets {
            let start = bucket * bucketSize
            guard start < sampleCount else {
                envelope.append(0.04)
                continue
            }
            let end = bucket == buckets - 1
                ? sampleCount
                : min(sampleCount, start + bucketSize)
            var energy = 0.0
            for index in start..<end {
                let mono = Double(left[index] + right[index]) * 0.5
                energy += mono * mono
            }
            let rms = sqrt(energy / Double(max(1, end - start)))
            let decibels = 20 * log10(max(rms, 0.000_000_001))
            let normalized = (decibels - floorDB) / (ceilingDB - floorDB)
            envelope.append(Float(min(1, max(0.04, normalized))))
        }
        return envelope
    }
}
