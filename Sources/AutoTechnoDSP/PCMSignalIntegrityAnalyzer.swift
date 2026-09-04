import Foundation

package struct PCMSignalIntegrityStatistics: Codable, Equatable, Sendable {
    package let sampleCount: Int
    package let finiteSampleCount: Int
    package let nonfiniteSampleCount: Int
    package let samplePeak: Double?
    package let samplePeakDBFS: Double?
    package let truePeak: Double?
    package let truePeakDBTP: Double?
    package let rms: Double?
    package let crestFactor: Double?
    package let dcOffset: Double?
    package let clippedSampleCount: Int
    package let subnormalSampleCount: Int
    package let exactZeroSampleCount: Int
    package let nearSilenceSampleCount: Int

    package var finite: Bool { nonfiniteSampleCount == 0 }
}

package struct PCMSignalIntegrityWindow: Codable, Equatable, Sendable {
    package let startFrame: Int
    package let frameCount: Int
    package let combined: PCMSignalIntegrityStatistics
    package let channels: [PCMSignalIntegrityStatistics]
    package let nearSilentFrameCount: Int
    package let longestNearSilentFrameRun: Int
}

package struct PCMSignalIntegrityEvidence: Codable, Equatable, Sendable {
    package static let schema = "autotechno-pcm-signal-integrity.v1"

    package let schema: String
    package let sampleRate: Double
    package let channelCount: Int
    package let frameCount: Int
    package let segmentFrameCount: Int
    package let combined: PCMSignalIntegrityStatistics
    package let channels: [PCMSignalIntegrityStatistics]
    package let nearSilentFrameCount: Int
    package let longestNearSilentFrameRun: Int
    package let segments: [PCMSignalIntegrityWindow]
}

package enum PCMSignalIntegrityAnalyzer {
    package static let analyzerVersion = "autotechno-pcm-signal-integrity.v1"
    package static let decibelFloor = -120.0
    package static let clippingAmplitude = 1.0
    package static let nearSilenceDBFS = -90.0
    package static let nearSilenceAmplitude = pow(10.0, nearSilenceDBFS / 20.0)
    package static let float32MinimumNormal = Double(Float.leastNormalMagnitude)
    package static let truePeakStandard = BS1770AudioEvidence.truePeakStandard
    package static let truePeakOversamplingFactor =
        BS1770AudioEvidence.truePeakOversamplingFactor

    package static func analyze(
        channels: [[Float]],
        sampleRate: Double,
        segmentFrameCount: Int
    ) -> PCMSignalIntegrityEvidence? {
        guard (1...2).contains(channels.count),
              sampleRate.isFinite,
              sampleRate > 0,
              segmentFrameCount > 0,
              let frameCount = channels.first?.count,
              channels.allSatisfy({ $0.count == frameCount }) else {
            return nil
        }

        let full = analyzeWindow(
            channels: channels,
            startFrame: 0,
            frameCount: frameCount
        )
        var segments: [PCMSignalIntegrityWindow] = []
        if frameCount > 0 {
            segments.reserveCapacity(
                (frameCount + segmentFrameCount - 1) / segmentFrameCount
            )
            var startFrame = 0
            while startFrame < frameCount {
                let count = min(segmentFrameCount, frameCount - startFrame)
                segments.append(analyzeWindow(
                    channels: channels,
                    startFrame: startFrame,
                    frameCount: count
                ))
                startFrame += count
            }
        }
        return PCMSignalIntegrityEvidence(
            schema: PCMSignalIntegrityEvidence.schema,
            sampleRate: sampleRate,
            channelCount: channels.count,
            frameCount: frameCount,
            segmentFrameCount: segmentFrameCount,
            combined: full.combined,
            channels: full.channels,
            nearSilentFrameCount: full.nearSilentFrameCount,
            longestNearSilentFrameRun: full.longestNearSilentFrameRun,
            segments: segments
        )
    }

    package static func decibels(amplitude: Double) -> Double? {
        guard amplitude.isFinite, amplitude >= 0 else { return nil }
        guard amplitude > 0 else { return decibelFloor }
        return max(decibelFloor, 20 * log10(amplitude))
    }

    private static func analyzeWindow(
        channels: [[Float]],
        startFrame: Int,
        frameCount: Int
    ) -> PCMSignalIntegrityWindow {
        let range = startFrame..<(startFrame + frameCount)
        let slices = channels.map { Array($0[range]) }
        let channelStatistics = slices.map(statistics)
        let combinedStatistics = combinedStatistics(
            channels: slices,
            channelStatistics: channelStatistics
        )
        let silence = frameSilence(channels: slices)
        return PCMSignalIntegrityWindow(
            startFrame: startFrame,
            frameCount: frameCount,
            combined: combinedStatistics,
            channels: channelStatistics,
            nearSilentFrameCount: silence.count,
            longestNearSilentFrameRun: silence.longestRun
        )
    }

    private static func statistics(
        samples: [Float]
    ) -> PCMSignalIntegrityStatistics {
        var finiteCount = 0
        var nonfiniteCount = 0
        var peak = 0.0
        var squareSum = 0.0
        var sum = 0.0
        var clipped = 0
        var subnormal = 0
        var exactZero = 0
        var nearSilence = 0
        for sample in samples {
            guard sample.isFinite else {
                nonfiniteCount += 1
                continue
            }
            let value = Double(sample)
            let magnitude = abs(value)
            finiteCount += 1
            peak = max(peak, magnitude)
            squareSum += value * value
            sum += value
            if magnitude >= clippingAmplitude { clipped += 1 }
            if magnitude > 0, magnitude < float32MinimumNormal { subnormal += 1 }
            if sample == 0 { exactZero += 1 }
            if magnitude <= nearSilenceAmplitude { nearSilence += 1 }
        }
        guard nonfiniteCount == 0 else {
            return PCMSignalIntegrityStatistics(
                sampleCount: samples.count,
                finiteSampleCount: finiteCount,
                nonfiniteSampleCount: nonfiniteCount,
                samplePeak: nil,
                samplePeakDBFS: nil,
                truePeak: nil,
                truePeakDBTP: nil,
                rms: nil,
                crestFactor: nil,
                dcOffset: nil,
                clippedSampleCount: clipped,
                subnormalSampleCount: subnormal,
                exactZeroSampleCount: exactZero,
                nearSilenceSampleCount: nearSilence
            )
        }
        let rms = finiteCount > 0 ? sqrt(squareSum / Double(finiteCount)) : 0
        let truePeak = BS1770AudioEvidence.truePeak(samples) ?? .nan
        let validTruePeak = truePeak.isFinite ? truePeak : nil
        return PCMSignalIntegrityStatistics(
            sampleCount: samples.count,
            finiteSampleCount: finiteCount,
            nonfiniteSampleCount: 0,
            samplePeak: peak,
            samplePeakDBFS: decibels(amplitude: peak),
            truePeak: validTruePeak,
            truePeakDBTP: validTruePeak.flatMap(decibels),
            rms: rms,
            crestFactor: rms > 0 ? peak / rms : 0,
            dcOffset: finiteCount > 0 ? sum / Double(finiteCount) : 0,
            clippedSampleCount: clipped,
            subnormalSampleCount: subnormal,
            exactZeroSampleCount: exactZero,
            nearSilenceSampleCount: nearSilence
        )
    }

    private static func combinedStatistics(
        channels: [[Float]],
        channelStatistics: [PCMSignalIntegrityStatistics]
    ) -> PCMSignalIntegrityStatistics {
        let sampleCount = channelStatistics.reduce(0) { $0 + $1.sampleCount }
        let finiteCount = channelStatistics.reduce(0) {
            $0 + $1.finiteSampleCount
        }
        let nonfiniteCount = channelStatistics.reduce(0) {
            $0 + $1.nonfiniteSampleCount
        }
        let clipped = channelStatistics.reduce(0) {
            $0 + $1.clippedSampleCount
        }
        let subnormal = channelStatistics.reduce(0) {
            $0 + $1.subnormalSampleCount
        }
        let exactZero = channelStatistics.reduce(0) {
            $0 + $1.exactZeroSampleCount
        }
        let nearSilence = channelStatistics.reduce(0) {
            $0 + $1.nearSilenceSampleCount
        }
        guard nonfiniteCount == 0 else {
            return PCMSignalIntegrityStatistics(
                sampleCount: sampleCount,
                finiteSampleCount: finiteCount,
                nonfiniteSampleCount: nonfiniteCount,
                samplePeak: nil,
                samplePeakDBFS: nil,
                truePeak: nil,
                truePeakDBTP: nil,
                rms: nil,
                crestFactor: nil,
                dcOffset: nil,
                clippedSampleCount: clipped,
                subnormalSampleCount: subnormal,
                exactZeroSampleCount: exactZero,
                nearSilenceSampleCount: nearSilence
            )
        }
        let peak = channelStatistics.compactMap(\.samplePeak).max() ?? 0
        let truePeak = channelStatistics.compactMap(\.truePeak).max() ?? 0
        var squareSum = 0.0
        var sum = 0.0
        for channel in channels {
            for sample in channel {
                let value = Double(sample)
                squareSum += value * value
                sum += value
            }
        }
        let rms = sampleCount > 0 ? sqrt(squareSum / Double(sampleCount)) : 0
        return PCMSignalIntegrityStatistics(
            sampleCount: sampleCount,
            finiteSampleCount: finiteCount,
            nonfiniteSampleCount: 0,
            samplePeak: peak,
            samplePeakDBFS: decibels(amplitude: peak),
            truePeak: truePeak,
            truePeakDBTP: decibels(amplitude: truePeak),
            rms: rms,
            crestFactor: rms > 0 ? peak / rms : 0,
            dcOffset: sampleCount > 0 ? sum / Double(sampleCount) : 0,
            clippedSampleCount: clipped,
            subnormalSampleCount: subnormal,
            exactZeroSampleCount: exactZero,
            nearSilenceSampleCount: nearSilence
        )
    }

    private static func frameSilence(
        channels: [[Float]]
    ) -> (count: Int, longestRun: Int) {
        let frameCount = channels.first?.count ?? 0
        var count = 0
        var currentRun = 0
        var longestRun = 0
        for frame in 0..<frameCount {
            let silent = channels.allSatisfy { channel in
                let sample = channel[frame]
                return sample.isFinite &&
                    abs(Double(sample)) <= nearSilenceAmplitude
            }
            if silent {
                count += 1
                currentRun += 1
                longestRun = max(longestRun, currentRun)
            } else {
                currentRun = 0
            }
        }
        return (count, longestRun)
    }
}
