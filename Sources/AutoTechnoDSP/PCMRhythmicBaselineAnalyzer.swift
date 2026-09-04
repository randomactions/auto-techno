import Foundation

package enum PCMRhythmicIntervalStatus: String, Codable, Equatable, Sendable {
    case available
    case unavailableNoOnsets = "unavailable-no-onsets"
    case unavailablePartialBar = "unavailable-partial-bar"
}

package enum PCMRhythmicComparisonAvailability:
    String, Codable, Equatable, Sendable {
    case available
    case unavailableNoOnsetsInEitherBar =
        "unavailable-no-onsets-in-either-bar"
}

package struct PCMRhythmicOnsetEvidence: Codable, Equatable, Sendable {
    package let onsetFrame: Int
    package let frameInBar: Int
    package let onsetSource: PCMTransientEnvelopeOnsetSource
    package let gridStep: Int
    package let quantizedFrameInBar: Int
    package let microtimingOffsetFrames: Int
    package let microtimingOffsetSteps: Double
}

package struct PCMRhythmicBarEvidence: Codable, Equatable, Sendable {
    package let index: Int
    package let startFrame: Int
    package let frameCount: Int
    package let complete: Bool
    package let exactSilentFrameCount: Int
    package let exactSilenceOccupancy: Double
    package let onsetCount: Int
    package let onsets: [PCMRhythmicOnsetEvidence]
    package let gridOnsetCounts: [Int]
    package let occupiedGridCellCount: Int
    package let restGridCellCount: Int
    package let restOccupancy: Double
    package let linearInterOnsetFrameIntervals: [Int]
    package let cyclicInterOnsetFrameIntervals: [Int]
    package let cyclicIntervalStatus: PCMRhythmicIntervalStatus
    package let meanAbsoluteMicrotimingSteps: Double?
    package let maximumAbsoluteMicrotimingSteps: Double?
    package let metricalDisplacement: Double?
    package let adjacentStrongRestCount: Int
    package let adjacentStrongRestPotential: Double?
    package let finite: Bool

    private enum CodingKeys: String, CodingKey {
        case index
        case startFrame
        case frameCount
        case complete
        case exactSilentFrameCount
        case exactSilenceOccupancy
        case onsetCount
        case onsets
        case gridOnsetCounts
        case occupiedGridCellCount
        case restGridCellCount
        case restOccupancy
        case linearInterOnsetFrameIntervals
        case cyclicInterOnsetFrameIntervals
        case cyclicIntervalStatus
        case meanAbsoluteMicrotimingSteps
        case maximumAbsoluteMicrotimingSteps
        case metricalDisplacement
        case adjacentStrongRestCount
        case adjacentStrongRestPotential
        case finite
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(startFrame, forKey: .startFrame)
        try container.encode(frameCount, forKey: .frameCount)
        try container.encode(complete, forKey: .complete)
        try container.encode(exactSilentFrameCount, forKey: .exactSilentFrameCount)
        try container.encode(exactSilenceOccupancy, forKey: .exactSilenceOccupancy)
        try container.encode(onsetCount, forKey: .onsetCount)
        try container.encode(onsets, forKey: .onsets)
        try container.encode(gridOnsetCounts, forKey: .gridOnsetCounts)
        try container.encode(occupiedGridCellCount, forKey: .occupiedGridCellCount)
        try container.encode(restGridCellCount, forKey: .restGridCellCount)
        try container.encode(restOccupancy, forKey: .restOccupancy)
        try container.encode(
            linearInterOnsetFrameIntervals,
            forKey: .linearInterOnsetFrameIntervals
        )
        try container.encode(
            cyclicInterOnsetFrameIntervals,
            forKey: .cyclicInterOnsetFrameIntervals
        )
        try container.encode(cyclicIntervalStatus, forKey: .cyclicIntervalStatus)
        try encodeNullable(
            meanAbsoluteMicrotimingSteps,
            forKey: .meanAbsoluteMicrotimingSteps,
            into: &container
        )
        try encodeNullable(
            maximumAbsoluteMicrotimingSteps,
            forKey: .maximumAbsoluteMicrotimingSteps,
            into: &container
        )
        try encodeNullable(
            metricalDisplacement,
            forKey: .metricalDisplacement,
            into: &container
        )
        try container.encode(adjacentStrongRestCount, forKey: .adjacentStrongRestCount)
        try encodeNullable(
            adjacentStrongRestPotential,
            forKey: .adjacentStrongRestPotential,
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

package struct PCMRhythmicBarComparison: Codable, Equatable, Sendable {
    package let referenceBarIndex: Int
    package let currentBarIndex: Int
    package let lagBars: Int
    package let availability: PCMRhythmicComparisonAvailability
    package let exactPCMRepeat: Bool
    package let exactOnsetFrameRepeat: Bool?
    package let gridMutationDistance: Double?
    package let gridSimilarity: Double?
    package let bestReferenceForwardRotationSteps: Int?
    package let bestRotationMutationDistance: Double?
    package let matchedMicrotimingDistanceSteps: Double?
    package let finite: Bool

    private enum CodingKeys: String, CodingKey {
        case referenceBarIndex
        case currentBarIndex
        case lagBars
        case availability
        case exactPCMRepeat
        case exactOnsetFrameRepeat
        case gridMutationDistance
        case gridSimilarity
        case bestReferenceForwardRotationSteps
        case bestRotationMutationDistance
        case matchedMicrotimingDistanceSteps
        case finite
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(referenceBarIndex, forKey: .referenceBarIndex)
        try container.encode(currentBarIndex, forKey: .currentBarIndex)
        try container.encode(lagBars, forKey: .lagBars)
        try container.encode(availability, forKey: .availability)
        try container.encode(exactPCMRepeat, forKey: .exactPCMRepeat)
        try encodeNullable(
            exactOnsetFrameRepeat,
            forKey: .exactOnsetFrameRepeat,
            into: &container
        )
        try encodeNullable(
            gridMutationDistance,
            forKey: .gridMutationDistance,
            into: &container
        )
        try encodeNullable(
            gridSimilarity,
            forKey: .gridSimilarity,
            into: &container
        )
        if let bestReferenceForwardRotationSteps {
            try container.encode(
                bestReferenceForwardRotationSteps,
                forKey: .bestReferenceForwardRotationSteps
            )
        } else {
            try container.encodeNil(forKey: .bestReferenceForwardRotationSteps)
        }
        try encodeNullable(
            bestRotationMutationDistance,
            forKey: .bestRotationMutationDistance,
            into: &container
        )
        try encodeNullable(
            matchedMicrotimingDistanceSteps,
            forKey: .matchedMicrotimingDistanceSteps,
            into: &container
        )
        try container.encode(finite, forKey: .finite)
    }

    private func encodeNullable<T: Encodable>(
        _ value: T?,
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

package struct PCMRhythmicSummary: Codable, Equatable, Sendable {
    package let barCount: Int
    package let completeBarCount: Int
    package let partialBarCount: Int
    package let exactSilentBarCount: Int
    package let barsWithOnsets: Int
    package let onsetCount: Int
    package let comparisonCount: Int
    package let unavailableComparisonCount: Int
    package let exactPCMRepeatCount: Int
    package let exactOnsetRepeatCount: Int
    package let meanOnsetsPerCompleteBar: Double?
    package let meanRestOccupancy: Double?
    package let meanExactSilenceOccupancy: Double?
    package let meanMetricalDisplacement: Double?
    package let meanAdjacentStrongRestPotential: Double?
    package let meanGridMutationDistance: Double?
    package let meanBestRotationMutationDistance: Double?
    package let finite: Bool

    private enum CodingKeys: String, CodingKey {
        case barCount
        case completeBarCount
        case partialBarCount
        case exactSilentBarCount
        case barsWithOnsets
        case onsetCount
        case comparisonCount
        case unavailableComparisonCount
        case exactPCMRepeatCount
        case exactOnsetRepeatCount
        case meanOnsetsPerCompleteBar
        case meanRestOccupancy
        case meanExactSilenceOccupancy
        case meanMetricalDisplacement
        case meanAdjacentStrongRestPotential
        case meanGridMutationDistance
        case meanBestRotationMutationDistance
        case finite
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(barCount, forKey: .barCount)
        try container.encode(completeBarCount, forKey: .completeBarCount)
        try container.encode(partialBarCount, forKey: .partialBarCount)
        try container.encode(exactSilentBarCount, forKey: .exactSilentBarCount)
        try container.encode(barsWithOnsets, forKey: .barsWithOnsets)
        try container.encode(onsetCount, forKey: .onsetCount)
        try container.encode(comparisonCount, forKey: .comparisonCount)
        try container.encode(
            unavailableComparisonCount,
            forKey: .unavailableComparisonCount
        )
        try container.encode(exactPCMRepeatCount, forKey: .exactPCMRepeatCount)
        try container.encode(exactOnsetRepeatCount, forKey: .exactOnsetRepeatCount)
        try encodeNullable(
            meanOnsetsPerCompleteBar,
            forKey: .meanOnsetsPerCompleteBar,
            into: &container
        )
        try encodeNullable(
            meanRestOccupancy,
            forKey: .meanRestOccupancy,
            into: &container
        )
        try encodeNullable(
            meanExactSilenceOccupancy,
            forKey: .meanExactSilenceOccupancy,
            into: &container
        )
        try encodeNullable(
            meanMetricalDisplacement,
            forKey: .meanMetricalDisplacement,
            into: &container
        )
        try encodeNullable(
            meanAdjacentStrongRestPotential,
            forKey: .meanAdjacentStrongRestPotential,
            into: &container
        )
        try encodeNullable(
            meanGridMutationDistance,
            forKey: .meanGridMutationDistance,
            into: &container
        )
        try encodeNullable(
            meanBestRotationMutationDistance,
            forKey: .meanBestRotationMutationDistance,
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

package struct PCMRhythmicBaselineEvidence: Codable, Equatable, Sendable {
    package static let schema = "autotechno-pcm-rhythmic-baseline.v1"

    package let schema: String
    package let sampleRate: Int
    package let sourceChannelCount: Int
    package let frameCount: Int
    package let barFrameCount: Int
    package let gridStepsPerBar: Int
    package let maximumComparisonLagBars: Int
    package let onsetAuthority: String
    package let scoreBindingStatus: String
    package let summary: PCMRhythmicSummary
    package let bars: [PCMRhythmicBarEvidence]
    package let comparisons: [PCMRhythmicBarComparison]
}

/// Detached descriptive rhythm evidence for exact local whole-mix PCM. It
/// composes the existing PCM-inferred onset authority and exact source samples;
/// it never promotes those inferences to accepted score events or a quality
/// preference.
package enum PCMRhythmicBaselineAnalyzer {
    package static let analyzerVersion =
        "autotechno-pcm-rhythmic-baseline-analyzer.v1"
    package static let bpm = 130.0
    package static let beatsPerBar = 4
    package static let gridStepsPerBar = 16
    package static let maximumComparisonLagBars = 4
    package static let monoFold = PCMTransientEnvelopeAnalyzer.monoFold
    package static let onsetAuthority = PCMTransientEnvelopeAnalyzer.onsetAuthority
    package static let scoreBindingStatus =
        "unavailable-whole-manifest-does-not-retain-score-events"
    package static let gridQuantization =
        "nearest-cyclic-sixteenth-ties-to-earlier-grid-line"
    package static let exactSilenceRule =
        "all-source-channels-exact-positive-or-negative-digital-zero"
    package static let metricalDisplacementDefinition =
        "quarter-zero-eighth-offbeat-one-half-sixteenth-offbeat-one"
    package static let adjacentStrongRestDefinition =
        "occupied-cell-followed-by-empty-cell-of-greater-quarter-eighth-sixteenth-strength"
    package static let mutationDistanceDefinition =
        "l1-grid-count-difference-over-combined-onset-count"
    package static let comparisonAvailabilityPolicy =
        "two-no-onset-bars-unavailable-not-perfect-repetition"
    package static let finalPartialBarPolicy =
        "describe-linear-facts-exclude-cyclic-and-lag-comparisons"

    package static func analyze(
        channels: [[Float]],
        sampleRate: Double
    ) -> PCMRhythmicBaselineEvidence? {
        guard sampleRate.isFinite, sampleRate > 0,
              sampleRate.rounded() == sampleRate,
              sampleRate <= Double(Int.max),
              (channels.count == 1 || channels.count == 2),
              let frameCount = channels.first?.count,
              frameCount > 0,
              channels.allSatisfy({ $0.count == frameCount }),
              channels.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
            return nil
        }
        let barFramesDouble = sampleRate * 240.0 / bpm
        guard barFramesDouble.isFinite,
              barFramesDouble >= 1,
              barFramesDouble <= Double(Int.max) else { return nil }
        let barFrameCount = Int(barFramesDouble.rounded())
        guard let transient = PCMTransientEnvelopeAnalyzer.analyze(
            channels: channels,
            sampleRate: sampleRate,
            segmentFrameCount: barFrameCount
        ) else { return nil }

        var bars: [PCMRhythmicBarEvidence] = []
        bars.reserveCapacity((frameCount + barFrameCount - 1) / barFrameCount)
        var startFrame = 0
        while startFrame < frameCount {
            let count = min(barFrameCount, frameCount - startFrame)
            let endFrame = startFrame + count
            let sourceEvents = transient.events.filter {
                $0.onsetFrame >= startFrame && $0.onsetFrame < endFrame
            }
            let bar = makeBar(
                index: bars.count,
                startFrame: startFrame,
                frameCount: count,
                barFrameCount: barFrameCount,
                channels: channels,
                events: sourceEvents
            )
            guard bar.finite else { return nil }
            bars.append(bar)
            startFrame = endFrame
        }

        var comparisons: [PCMRhythmicBarComparison] = []
        for currentIndex in bars.indices where bars[currentIndex].complete {
            let maximumLag = min(maximumComparisonLagBars, currentIndex)
            guard maximumLag > 0 else { continue }
            for lag in 1...maximumLag {
                let referenceIndex = currentIndex - lag
                guard bars[referenceIndex].complete else { continue }
                let comparison = compare(
                    reference: bars[referenceIndex],
                    current: bars[currentIndex],
                    channels: channels,
                    barFrameCount: barFrameCount,
                    lag: lag
                )
                guard comparison.finite else { return nil }
                comparisons.append(comparison)
            }
        }
        let summary = summarize(bars: bars, comparisons: comparisons)
        guard summary.finite else { return nil }
        return PCMRhythmicBaselineEvidence(
            schema: PCMRhythmicBaselineEvidence.schema,
            sampleRate: Int(sampleRate),
            sourceChannelCount: channels.count,
            frameCount: frameCount,
            barFrameCount: barFrameCount,
            gridStepsPerBar: gridStepsPerBar,
            maximumComparisonLagBars: maximumComparisonLagBars,
            onsetAuthority: onsetAuthority,
            scoreBindingStatus: scoreBindingStatus,
            summary: summary,
            bars: bars,
            comparisons: comparisons
        )
    }

    private static func makeBar(
        index: Int,
        startFrame: Int,
        frameCount: Int,
        barFrameCount: Int,
        channels: [[Float]],
        events: [PCMTransientEnvelopeEventEvidence]
    ) -> PCMRhythmicBarEvidence {
        let complete = frameCount == barFrameCount
        let onsets = events.map { event -> PCMRhythmicOnsetEvidence in
            let frameInBar = event.onsetFrame - startFrame
            let quantized = quantize(
                frameInBar: frameInBar,
                barFrameCount: barFrameCount
            )
            let offset = frameInBar - quantized.frame
            return PCMRhythmicOnsetEvidence(
                onsetFrame: event.onsetFrame,
                frameInBar: frameInBar,
                onsetSource: event.onsetSource,
                gridStep: quantized.step,
                quantizedFrameInBar: quantized.frame,
                microtimingOffsetFrames: offset,
                microtimingOffsetSteps:
                    Double(offset) * Double(gridStepsPerBar) /
                    Double(barFrameCount)
            )
        }
        var counts = [Int](repeating: 0, count: gridStepsPerBar)
        for onset in onsets { counts[onset.gridStep] += 1 }
        let occupied = counts.reduce(into: 0) { if $1 > 0 { $0 += 1 } }
        let exactSilentFrames = (0..<frameCount).reduce(into: 0) { result, offset in
            if channels.allSatisfy({ $0[startFrame + offset] == 0 }) {
                result += 1
            }
        }
        let sortedFrames = onsets.map(\.frameInBar).sorted()
        let linearIntervals = zip(sortedFrames, sortedFrames.dropFirst()).map {
            $0.1 - $0.0
        }
        let cyclicStatus: PCMRhythmicIntervalStatus
        let cyclicIntervals: [Int]
        if !complete {
            cyclicStatus = .unavailablePartialBar
            cyclicIntervals = []
        } else if sortedFrames.isEmpty {
            cyclicStatus = .unavailableNoOnsets
            cyclicIntervals = []
        } else if sortedFrames.count == 1 {
            cyclicStatus = .available
            cyclicIntervals = [barFrameCount]
        } else {
            cyclicStatus = .available
            cyclicIntervals = linearIntervals + [
                barFrameCount - sortedFrames[sortedFrames.count - 1] +
                    sortedFrames[0],
            ]
        }
        let absoluteOffsets = onsets.map { abs($0.microtimingOffsetSteps) }
        let meanMicrotiming = mean(absoluteOffsets)
        let maximumMicrotiming = absoluteOffsets.max()
        let displacement = mean(onsets.map { displacementWeight($0.gridStep) })
        let adjacentStrongRestCount = counts.indices.reduce(into: 0) { value, step in
            let next = (step + 1) % gridStepsPerBar
            if counts[step] > 0,
               counts[next] == 0,
               metricalStrength(next) > metricalStrength(step) {
                value += 1
            }
        }
        let adjacentPotential = occupied > 0
            ? Double(adjacentStrongRestCount) / Double(occupied)
            : nil
        let finiteValues = [
            Double(exactSilentFrames) / Double(frameCount),
            Double(gridStepsPerBar - occupied) / Double(gridStepsPerBar),
            meanMicrotiming,
            maximumMicrotiming,
            displacement,
            adjacentPotential,
        ].compactMap { $0 }
        return PCMRhythmicBarEvidence(
            index: index,
            startFrame: startFrame,
            frameCount: frameCount,
            complete: complete,
            exactSilentFrameCount: exactSilentFrames,
            exactSilenceOccupancy: Double(exactSilentFrames) / Double(frameCount),
            onsetCount: onsets.count,
            onsets: onsets,
            gridOnsetCounts: counts,
            occupiedGridCellCount: occupied,
            restGridCellCount: gridStepsPerBar - occupied,
            restOccupancy:
                Double(gridStepsPerBar - occupied) / Double(gridStepsPerBar),
            linearInterOnsetFrameIntervals: linearIntervals,
            cyclicInterOnsetFrameIntervals: cyclicIntervals,
            cyclicIntervalStatus: cyclicStatus,
            meanAbsoluteMicrotimingSteps: meanMicrotiming,
            maximumAbsoluteMicrotimingSteps: maximumMicrotiming,
            metricalDisplacement: displacement,
            adjacentStrongRestCount: adjacentStrongRestCount,
            adjacentStrongRestPotential: adjacentPotential,
            finite: finiteValues.allSatisfy(\.isFinite)
        )
    }

    private static func quantize(
        frameInBar: Int,
        barFrameCount: Int
    ) -> (step: Int, frame: Int) {
        var bestLine = 0
        var bestFrame = 0
        var bestDistance = abs(frameInBar)
        for line in 1...gridStepsPerBar {
            let target = Int((
                Double(line) * Double(barFrameCount) /
                Double(gridStepsPerBar)
            ).rounded())
            let distance = abs(frameInBar - target)
            if distance < bestDistance {
                bestLine = line
                bestFrame = target
                bestDistance = distance
            }
        }
        return (bestLine % gridStepsPerBar, bestFrame)
    }

    private static func displacementWeight(_ step: Int) -> Double {
        if step.isMultiple(of: 4) { return 0 }
        if step.isMultiple(of: 2) { return 0.5 }
        return 1
    }

    private static func metricalStrength(_ step: Int) -> Int {
        if step.isMultiple(of: 4) { return 3 }
        if step.isMultiple(of: 2) { return 2 }
        return 1
    }

    private static func compare(
        reference: PCMRhythmicBarEvidence,
        current: PCMRhythmicBarEvidence,
        channels: [[Float]],
        barFrameCount: Int,
        lag: Int
    ) -> PCMRhythmicBarComparison {
        let exactPCM = exactPCMRepeat(
            referenceStart: reference.startFrame,
            currentStart: current.startFrame,
            frameCount: barFrameCount,
            channels: channels
        )
        if reference.onsets.isEmpty && current.onsets.isEmpty {
            return PCMRhythmicBarComparison(
                referenceBarIndex: reference.index,
                currentBarIndex: current.index,
                lagBars: lag,
                availability: .unavailableNoOnsetsInEitherBar,
                exactPCMRepeat: exactPCM,
                exactOnsetFrameRepeat: nil,
                gridMutationDistance: nil,
                gridSimilarity: nil,
                bestReferenceForwardRotationSteps: nil,
                bestRotationMutationDistance: nil,
                matchedMicrotimingDistanceSteps: nil,
                finite: true
            )
        }
        let referenceFrames = reference.onsets.map(\.frameInBar)
        let currentFrames = current.onsets.map(\.frameInBar)
        let distance = mutationDistance(
            reference.gridOnsetCounts,
            current.gridOnsetCounts
        )
        let similarity = gridSimilarity(
            reference.gridOnsetCounts,
            current.gridOnsetCounts
        )
        var bestShift = 0
        var bestDistance = Double.infinity
        for shift in 0..<gridStepsPerBar {
            var rotated = [Int](repeating: 0, count: gridStepsPerBar)
            for step in 0..<gridStepsPerBar {
                rotated[(step + shift) % gridStepsPerBar] =
                    reference.gridOnsetCounts[step]
            }
            let candidate = mutationDistance(rotated, current.gridOnsetCounts)
            if candidate < bestDistance {
                bestDistance = candidate
                bestShift = shift
            }
        }
        let microtimingDistance = matchedMicrotimingDistance(
            reference: reference,
            current: current
        )
        let values = [distance, similarity, bestDistance, microtimingDistance]
            .compactMap { $0 }
        return PCMRhythmicBarComparison(
            referenceBarIndex: reference.index,
            currentBarIndex: current.index,
            lagBars: lag,
            availability: .available,
            exactPCMRepeat: exactPCM,
            exactOnsetFrameRepeat: referenceFrames == currentFrames,
            gridMutationDistance: distance,
            gridSimilarity: similarity,
            bestReferenceForwardRotationSteps: bestShift,
            bestRotationMutationDistance: bestDistance,
            matchedMicrotimingDistanceSteps: microtimingDistance,
            finite: values.allSatisfy(\.isFinite)
        )
    }

    private static func exactPCMRepeat(
        referenceStart: Int,
        currentStart: Int,
        frameCount: Int,
        channels: [[Float]]
    ) -> Bool {
        for channel in channels {
            for offset in 0..<frameCount where
                channel[referenceStart + offset].bitPattern !=
                channel[currentStart + offset].bitPattern {
                return false
            }
        }
        return true
    }

    private static func mutationDistance(_ first: [Int], _ second: [Int]) -> Double {
        let numerator = zip(first, second).reduce(0) { result, values in
            result + abs(values.0 - values.1)
        }
        let denominator = first.reduce(0, +) + second.reduce(0, +)
        return denominator > 0 ? Double(numerator) / Double(denominator) : 0
    }

    private static func gridSimilarity(_ first: [Int], _ second: [Int]) -> Double {
        let intersection = zip(first, second).reduce(0) {
            $0 + min($1.0, $1.1)
        }
        let union = zip(first, second).reduce(0) {
            $0 + max($1.0, $1.1)
        }
        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    private static func matchedMicrotimingDistance(
        reference: PCMRhythmicBarEvidence,
        current: PCMRhythmicBarEvidence
    ) -> Double? {
        var distances: [Double] = []
        for step in 0..<gridStepsPerBar {
            let first = reference.onsets
                .filter { $0.gridStep == step }
                .map(\.microtimingOffsetSteps)
                .sorted()
            let second = current.onsets
                .filter { $0.gridStep == step }
                .map(\.microtimingOffsetSteps)
                .sorted()
            for (left, right) in zip(first, second) {
                distances.append(abs(left - right))
            }
        }
        return mean(distances)
    }

    private static func summarize(
        bars: [PCMRhythmicBarEvidence],
        comparisons: [PCMRhythmicBarComparison]
    ) -> PCMRhythmicSummary {
        let complete = bars.filter(\.complete)
        let available = comparisons.filter { $0.availability == .available }
        let displacement = complete.compactMap(\.metricalDisplacement)
        let strongRest = complete.compactMap(\.adjacentStrongRestPotential)
        let mutation = available.compactMap(\.gridMutationDistance)
        let rotated = available.compactMap(\.bestRotationMutationDistance)
        let values = [
            mean(complete.map { Double($0.onsetCount) }),
            mean(complete.map(\.restOccupancy)),
            mean(complete.map(\.exactSilenceOccupancy)),
            mean(displacement),
            mean(strongRest),
            mean(mutation),
            mean(rotated),
        ].compactMap { $0 }
        return PCMRhythmicSummary(
            barCount: bars.count,
            completeBarCount: complete.count,
            partialBarCount: bars.count - complete.count,
            exactSilentBarCount: bars.filter {
                $0.exactSilentFrameCount == $0.frameCount
            }.count,
            barsWithOnsets: bars.filter { $0.onsetCount > 0 }.count,
            onsetCount: bars.reduce(0) { $0 + $1.onsetCount },
            comparisonCount: comparisons.count,
            unavailableComparisonCount:
                comparisons.count - available.count,
            exactPCMRepeatCount: available.filter(\.exactPCMRepeat).count,
            exactOnsetRepeatCount: available.filter {
                $0.exactOnsetFrameRepeat == true
            }.count,
            meanOnsetsPerCompleteBar:
                mean(complete.map { Double($0.onsetCount) }),
            meanRestOccupancy: mean(complete.map(\.restOccupancy)),
            meanExactSilenceOccupancy:
                mean(complete.map(\.exactSilenceOccupancy)),
            meanMetricalDisplacement: mean(displacement),
            meanAdjacentStrongRestPotential: mean(strongRest),
            meanGridMutationDistance: mean(mutation),
            meanBestRotationMutationDistance: mean(rotated),
            finite: values.allSatisfy(\.isFinite)
        )
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
