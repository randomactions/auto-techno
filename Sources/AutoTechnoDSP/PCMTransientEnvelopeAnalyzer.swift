import Foundation

/// Reusable state for the legacy whole-mix transient-density definition.
/// Processing order and constants intentionally match `MusicalQualityMetrics`.
package struct PCMTransientDensityTracker: Sendable {
    package static let detectionThreshold = 0.055
    package static let refractorySeconds = 0.035
    package static let referenceSampleRate = 48_000.0
    package static let referenceEnvelopeCoefficient = 0.08

    package private(set) var transientCount = 0
    package private(set) var processedFrameCount = 0

    private let refractoryFrameCount: Int
    private let envelopeCoefficient: Double
    private var previousEnvelope = 0.0
    private var lastTransientFrame: Int

    package init(sampleRate: Double) {
        refractoryFrameCount = max(
            1,
            Int(sampleRate * Self.refractorySeconds)
        )
        envelopeCoefficient = 1 - pow(
            1 - Self.referenceEnvelopeCoefficient,
            Self.referenceSampleRate / sampleRate
        )
        lastTransientFrame = -refractoryFrameCount
    }

    /// Returns `true` at the exact frame counted by the legacy detector.
    package mutating func process(_ monoSample: Double) -> Bool {
        let magnitude = abs(monoSample)
        let detected = magnitude - previousEnvelope > Self.detectionThreshold &&
            processedFrameCount - lastTransientFrame >= refractoryFrameCount
        if detected {
            transientCount += 1
            lastTransientFrame = processedFrameCount
        }
        previousEnvelope +=
            (magnitude - previousEnvelope) * envelopeCoefficient
        processedFrameCount += 1
        return detected
    }
}

package enum PCMTransientEnvelopeOnsetSource: String, Codable, Sendable {
    case activityRise = "pcm-activity-rise"
    case legacyFlux = "legacy-flux"
    case activityRiseAndLegacyFlux = "pcm-activity-rise-and-legacy-flux"
}

package enum PCMTransientEnvelopeEndSource: String, Codable, Sendable {
    case nextEvent = "next-event"
    case fixedWindow = "fixed-window"
    case sourceEnd = "source-end"
}

package struct PCMTransientEnvelopeEventEvidence:
    Codable, Equatable, Sendable {
    package let index: Int
    package let onsetFrame: Int
    package let onsetSource: PCMTransientEnvelopeOnsetSource
    package let analysisEndFrame: Int
    package let analysisEndSource: PCMTransientEnvelopeEndSource
    package let peakFrame: Int
    package let peakAmplitude: Double
    package let attack10Frame: Int
    package let attack90Frame: Int
    package let attackRiseFrameCount: Int
    package let attackRiseSeconds: Double
    package let attackMeanNormalizedEnvelope: Double
    package let decayFrameCount: Int
    package let decayActiveFrameCount: Int
    package let decayOccupancy: Double
    package let decay10Frame: Int?
    package let rms: Double
    package let crestFactor: Double
    package let finite: Bool

    private enum CodingKeys: String, CodingKey {
        case index
        case onsetFrame
        case onsetSource
        case analysisEndFrame
        case analysisEndSource
        case peakFrame
        case peakAmplitude
        case attack10Frame
        case attack90Frame
        case attackRiseFrameCount
        case attackRiseSeconds
        case attackMeanNormalizedEnvelope
        case decayFrameCount
        case decayActiveFrameCount
        case decayOccupancy
        case decay10Frame
        case rms
        case crestFactor
        case finite
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(onsetFrame, forKey: .onsetFrame)
        try container.encode(onsetSource, forKey: .onsetSource)
        try container.encode(analysisEndFrame, forKey: .analysisEndFrame)
        try container.encode(analysisEndSource, forKey: .analysisEndSource)
        try container.encode(peakFrame, forKey: .peakFrame)
        try container.encode(peakAmplitude, forKey: .peakAmplitude)
        try container.encode(attack10Frame, forKey: .attack10Frame)
        try container.encode(attack90Frame, forKey: .attack90Frame)
        try container.encode(attackRiseFrameCount, forKey: .attackRiseFrameCount)
        try container.encode(attackRiseSeconds, forKey: .attackRiseSeconds)
        try container.encode(
            attackMeanNormalizedEnvelope,
            forKey: .attackMeanNormalizedEnvelope
        )
        try container.encode(decayFrameCount, forKey: .decayFrameCount)
        try container.encode(
            decayActiveFrameCount,
            forKey: .decayActiveFrameCount
        )
        try container.encode(decayOccupancy, forKey: .decayOccupancy)
        if let decay10Frame {
            try container.encode(decay10Frame, forKey: .decay10Frame)
        } else {
            try container.encodeNil(forKey: .decay10Frame)
        }
        try container.encode(rms, forKey: .rms)
        try container.encode(crestFactor, forKey: .crestFactor)
        try container.encode(finite, forKey: .finite)
    }
}

package struct PCMTransientEnvelopeSummary: Codable, Equatable, Sendable {
    package let frameCount: Int
    package let durationSeconds: Double
    package let legacyTransientCount: Int
    package let legacyTransientDensityPerSecond: Double
    package let shapeEventCount: Int
    package let shapeEventDensityPerSecond: Double
    package let crestFactor: Double
    package let attackRiseSecondsMean: Double?
    package let attackMeanNormalizedEnvelopeMean: Double?
    package let decayOccupancyMean: Double?
    package let eventCrestFactorMean: Double?
    package let finite: Bool

    private enum CodingKeys: String, CodingKey {
        case frameCount
        case durationSeconds
        case legacyTransientCount
        case legacyTransientDensityPerSecond
        case shapeEventCount
        case shapeEventDensityPerSecond
        case crestFactor
        case attackRiseSecondsMean
        case attackMeanNormalizedEnvelopeMean
        case decayOccupancyMean
        case eventCrestFactorMean
        case finite
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frameCount, forKey: .frameCount)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(
            legacyTransientCount,
            forKey: .legacyTransientCount
        )
        try container.encode(
            legacyTransientDensityPerSecond,
            forKey: .legacyTransientDensityPerSecond
        )
        try container.encode(shapeEventCount, forKey: .shapeEventCount)
        try container.encode(
            shapeEventDensityPerSecond,
            forKey: .shapeEventDensityPerSecond
        )
        try container.encode(crestFactor, forKey: .crestFactor)
        try encodeNullable(
            attackRiseSecondsMean,
            forKey: .attackRiseSecondsMean,
            into: &container
        )
        try encodeNullable(
            attackMeanNormalizedEnvelopeMean,
            forKey: .attackMeanNormalizedEnvelopeMean,
            into: &container
        )
        try encodeNullable(
            decayOccupancyMean,
            forKey: .decayOccupancyMean,
            into: &container
        )
        try encodeNullable(
            eventCrestFactorMean,
            forKey: .eventCrestFactorMean,
            into: &container
        )
        try container.encode(finite, forKey: .finite)
    }

    private func encodeNullable(
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

package struct PCMTransientEnvelopeSegmentEvidence:
    Codable, Equatable, Sendable {
    package let startFrame: Int
    package let frameCount: Int
    package let summary: PCMTransientEnvelopeSummary
}

package struct PCMTransientEnvelopeEvidence: Codable, Equatable, Sendable {
    package static let schema = "autotechno-pcm-transient-envelope.v1"

    package let schema: String
    package let sampleRate: Int
    package let sourceChannelCount: Int
    package let frameCount: Int
    package let segmentFrameCount: Int
    package let activityGateAmplitude: Double
    package let summary: PCMTransientEnvelopeSummary
    package let events: [PCMTransientEnvelopeEventEvidence]
    package let segments: [PCMTransientEnvelopeSegmentEvidence]
}

/// Detached, descriptive event geometry for exact local corpus PCM. The legacy
/// detector remains a separately named evidence family. Shape events are PCM
/// inferences, never score or renderer event claims.
package enum PCMTransientEnvelopeAnalyzer {
    package static let analyzerVersion =
        "autotechno-pcm-transient-envelope-analyzer.v1"
    package static let monoFold = "arithmetic-mean-of-source-channels"
    package static let onsetAuthority =
        "pcm-inferred-activity-rise-or-legacy-flux-not-score-bound"
    package static let activityRelativeToSourcePeak = 0.04
    package static let activityAbsoluteFloor = 0.000_01
    package static let envelopeReleaseSeconds = 0.010
    package static let peakSearchSeconds = 0.090
    package static let eventWindowSeconds = 240.0 / 130.0 / 8.0
    package static let attackLowerFraction = 0.10
    package static let attackUpperFraction = 0.90
    package static let decayActivityFraction = 0.04
    package static let decayLandmarkFraction = 0.10
    package static let noEventPolicy =
        "valid-zero-count-null-shape-aggregates"

    package static func analyze(
        channels: [[Float]],
        sampleRate: Double,
        segmentFrameCount: Int
    ) -> PCMTransientEnvelopeEvidence? {
        guard sampleRate.isFinite, sampleRate > 0,
              sampleRate.rounded() == sampleRate,
              sampleRate <= Double(Int.max),
              !channels.isEmpty,
              channels.count <= 2,
              let frameCount = channels.first?.count,
              frameCount > 0,
              channels.allSatisfy({ $0.count == frameCount }),
              channels.allSatisfy({ $0.allSatisfy(\.isFinite) }),
              segmentFrameCount > 0 else {
            return nil
        }

        let mono = foldToMono(channels, frameCount: frameCount)
        let sourcePeak = mono.reduce(0.0) { max($0, abs($1)) }
        let activityGate = min(
            sourcePeak,
            max(activityAbsoluteFloor, sourcePeak * activityRelativeToSourcePeak)
        )
        let envelope = activityEnvelope(mono, sampleRate: sampleRate)

        var legacyTracker = PCMTransientDensityTracker(sampleRate: sampleRate)
        var legacyFrames: [Int] = []
        legacyFrames.reserveCapacity(max(1, frameCount / Int(sampleRate)))
        for sample in mono {
            if legacyTracker.process(sample) {
                legacyFrames.append(legacyTracker.processedFrameCount - 1)
            }
        }

        let candidates = onsetCandidates(
            envelope: envelope,
            activityGate: activityGate,
            legacyFrames: legacyFrames,
            sampleRate: sampleRate
        )
        let events = makeEvents(
            candidates: candidates,
            mono: mono,
            envelope: envelope,
            sampleRate: sampleRate
        )
        guard events.count == candidates.count,
              events.allSatisfy(\.finite) else { return nil }

        let summary = summarize(
            mono: mono[mono.startIndex..<mono.endIndex],
            frameCount: frameCount,
            legacyTransientCount: legacyFrames.count,
            events: events,
            sampleRate: sampleRate
        )
        guard summary.finite else { return nil }

        var segments: [PCMTransientEnvelopeSegmentEvidence] = []
        var start = 0
        while start < frameCount {
            let count = min(segmentFrameCount, frameCount - start)
            let end = start + count
            let segmentEvents = events.filter {
                $0.onsetFrame >= start && $0.onsetFrame < end
            }
            let segmentLegacyCount = legacyFrames.reduce(into: 0) {
                if $1 >= start && $1 < end { $0 += 1 }
            }
            let segmentSummary = summarize(
                mono: mono[start..<end],
                frameCount: count,
                legacyTransientCount: segmentLegacyCount,
                events: segmentEvents,
                sampleRate: sampleRate
            )
            guard segmentSummary.finite else { return nil }
            segments.append(PCMTransientEnvelopeSegmentEvidence(
                startFrame: start,
                frameCount: count,
                summary: segmentSummary
            ))
            start = end
        }

        return PCMTransientEnvelopeEvidence(
            schema: PCMTransientEnvelopeEvidence.schema,
            sampleRate: Int(sampleRate),
            sourceChannelCount: channels.count,
            frameCount: frameCount,
            segmentFrameCount: segmentFrameCount,
            activityGateAmplitude: activityGate,
            summary: summary,
            events: events,
            segments: segments
        )
    }

    private struct OnsetCandidate {
        let frame: Int
        let activityRise: Bool
        let legacyFlux: Bool
    }

    private static func foldToMono(
        _ channels: [[Float]], frameCount: Int
    ) -> [Double] {
        let divisor = Double(channels.count)
        var mono = [Double](repeating: 0, count: frameCount)
        for channel in channels {
            for frame in 0..<frameCount {
                mono[frame] += Double(channel[frame]) / divisor
            }
        }
        return mono
    }

    private static func activityEnvelope(
        _ mono: [Double], sampleRate: Double
    ) -> [Double] {
        let release = 1 - exp(-1 / (sampleRate * envelopeReleaseSeconds))
        var state = 0.0
        return mono.map { sample in
            let magnitude = abs(sample)
            if magnitude >= state {
                state = magnitude
            } else {
                state += (magnitude - state) * release
            }
            return state
        }
    }

    private static func onsetCandidates(
        envelope: [Double],
        activityGate: Double,
        legacyFrames: [Int],
        sampleRate: Double
    ) -> [OnsetCandidate] {
        guard activityGate > 0 else { return [] }
        var raw: [OnsetCandidate] = []
        var active = false
        let legacySet = Set(legacyFrames)
        for frame in envelope.indices {
            let nowActive = envelope[frame] >= activityGate
            let rise = nowActive && !active
            let legacy = legacySet.contains(frame)
            if rise || legacy {
                raw.append(OnsetCandidate(
                    frame: frame,
                    activityRise: rise,
                    legacyFlux: legacy
                ))
            }
            active = nowActive
        }
        guard !raw.isEmpty else { return [] }

        let mergeFrames = max(
            1,
            Int((sampleRate * PCMTransientDensityTracker.refractorySeconds).rounded())
        )
        var merged: [OnsetCandidate] = []
        for candidate in raw {
            if let previous = merged.last,
               candidate.frame - previous.frame < mergeFrames {
                merged[merged.count - 1] = OnsetCandidate(
                    frame: previous.frame,
                    activityRise:
                        previous.activityRise || candidate.activityRise,
                    legacyFlux: previous.legacyFlux || candidate.legacyFlux
                )
            } else {
                merged.append(candidate)
            }
        }
        return merged
    }

    private static func makeEvents(
        candidates: [OnsetCandidate],
        mono: [Double],
        envelope: [Double],
        sampleRate: Double
    ) -> [PCMTransientEnvelopeEventEvidence] {
        let fixedWindow = max(1, Int((sampleRate * eventWindowSeconds).rounded()))
        let peakSearch = max(1, Int((sampleRate * peakSearchSeconds).rounded()))
        return candidates.enumerated().compactMap { index, candidate in
            let fixedEnd = min(mono.count, candidate.frame + fixedWindow)
            let nextOnset = index + 1 < candidates.count
                ? candidates[index + 1].frame
                : nil
            let end: Int
            let endSource: PCMTransientEnvelopeEndSource
            if let nextOnset, nextOnset < fixedEnd {
                end = nextOnset
                endSource = .nextEvent
            } else if fixedEnd < mono.count {
                end = fixedEnd
                endSource = .fixedWindow
            } else {
                end = mono.count
                endSource = .sourceEnd
            }
            guard candidate.frame < end else { return nil }

            let searchEnd = min(end, candidate.frame + peakSearch)
            guard let peakFrame = envelope[candidate.frame..<searchEnd]
                .indices.max(by: { envelope[$0] < envelope[$1] }) else {
                return nil
            }
            let peak = envelope[peakFrame]
            guard peak.isFinite, peak > 0 else { return nil }
            let lower = peak * attackLowerFraction
            let upper = peak * attackUpperFraction
            let attack10 = envelope[candidate.frame...peakFrame]
                .firstIndex(where: { $0 >= lower }) ?? candidate.frame
            let attack90 = envelope[attack10...peakFrame]
                .firstIndex(where: { $0 >= upper }) ?? peakFrame
            let attackFrames = attack90 - attack10
            let attackSlice = envelope[attack10...attack90]
            let attackMean = attackSlice.reduce(0, +) /
                (Double(attackSlice.count) * peak)

            let decayGate = max(activityAbsoluteFloor, peak * decayActivityFraction)
            let decayRange = peakFrame..<end
            let decayActive = envelope[decayRange].reduce(into: 0) {
                if $1 >= decayGate { $0 += 1 }
            }
            let decay10 = envelope[decayRange].firstIndex {
                $0 <= peak * decayLandmarkFraction
            }
            let samples = mono[candidate.frame..<end]
            let eventPeak = samples.reduce(0.0) { max($0, abs($1)) }
            let squareSum = samples.reduce(0.0) { $0 + $1 * $1 }
            let rms = sqrt(squareSum / Double(samples.count))
            let crest = rms > 0 ? eventPeak / rms : 0
            let onsetSource: PCMTransientEnvelopeOnsetSource
            switch (candidate.activityRise, candidate.legacyFlux) {
            case (true, true): onsetSource = .activityRiseAndLegacyFlux
            case (true, false): onsetSource = .activityRise
            case (false, true): onsetSource = .legacyFlux
            case (false, false): return nil
            }
            let finite = [
                peak, attackMean, rms, crest,
                Double(decayActive) / Double(decayRange.count),
            ].allSatisfy(\.isFinite)
            return PCMTransientEnvelopeEventEvidence(
                index: index,
                onsetFrame: candidate.frame,
                onsetSource: onsetSource,
                analysisEndFrame: end,
                analysisEndSource: endSource,
                peakFrame: peakFrame,
                peakAmplitude: peak,
                attack10Frame: attack10,
                attack90Frame: attack90,
                attackRiseFrameCount: attackFrames,
                attackRiseSeconds: Double(attackFrames) / sampleRate,
                attackMeanNormalizedEnvelope: attackMean,
                decayFrameCount: decayRange.count,
                decayActiveFrameCount: decayActive,
                decayOccupancy: Double(decayActive) / Double(decayRange.count),
                decay10Frame: decay10,
                rms: rms,
                crestFactor: crest,
                finite: finite
            )
        }
    }

    private static func summarize(
        mono: ArraySlice<Double>,
        frameCount: Int,
        legacyTransientCount: Int,
        events: [PCMTransientEnvelopeEventEvidence],
        sampleRate: Double
    ) -> PCMTransientEnvelopeSummary {
        let duration = Double(frameCount) / sampleRate
        let peak = mono.reduce(0.0) { max($0, abs($1)) }
        let squareSum = mono.reduce(0.0) { $0 + $1 * $1 }
        let rms = sqrt(squareSum / Double(frameCount))
        let crest = rms > 0 ? peak / rms : 0
        let eventDivisor = Double(events.count)
        let attackRise = events.isEmpty ? nil :
            events.reduce(0.0) { $0 + $1.attackRiseSeconds } / eventDivisor
        let attackMean = events.isEmpty ? nil :
            events.reduce(0.0) { $0 + $1.attackMeanNormalizedEnvelope } /
                eventDivisor
        let decayOccupancy = events.isEmpty ? nil :
            events.reduce(0.0) { $0 + $1.decayOccupancy } / eventDivisor
        let eventCrest = events.isEmpty ? nil :
            events.reduce(0.0) { $0 + $1.crestFactor } / eventDivisor
        let values = [
            duration,
            Double(legacyTransientCount) / duration,
            Double(events.count) / duration,
            crest,
            attackRise,
            attackMean,
            decayOccupancy,
            eventCrest,
        ].compactMap { $0 }
        return PCMTransientEnvelopeSummary(
            frameCount: frameCount,
            durationSeconds: duration,
            legacyTransientCount: legacyTransientCount,
            legacyTransientDensityPerSecond:
                Double(legacyTransientCount) / duration,
            shapeEventCount: events.count,
            shapeEventDensityPerSecond: Double(events.count) / duration,
            crestFactor: crest,
            attackRiseSecondsMean: attackRise,
            attackMeanNormalizedEnvelopeMean: attackMean,
            decayOccupancyMean: decayOccupancy,
            eventCrestFactorMean: eventCrest,
            finite: values.allSatisfy(\.isFinite)
        )
    }
}
