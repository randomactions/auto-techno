import Foundation

package enum PCMSectionBoundaryMarkerKind:
    String, Codable, CaseIterable, Equatable, Sendable {
    case sessionStart = "session-start"
    case phraseStart = "phrase-start"
    case phraseKindChange = "phrase-kind-change"
    case interlockChapterChange = "interlock-chapter-change"
}

package enum PCMSectionBoundaryRecoveryStatus:
    String, Codable, Equatable, Sendable {
    case sustainedObserved = "sustained-observed"
    case notObservedWithinHorizon = "not-observed-within-horizon"
    case missingReference = "unavailable-missing-reference"
    case missingPost = "unavailable-missing-post"
    case missingMetric = "unavailable-missing-metric"
}

package struct PCMSectionBoundaryScoreBar: Codable, Equatable, Sendable {
    package let phraseIndex: Int
    package let phraseKind: String
    package let absoluteBar: Int
    package let barIndexInPhrase: Int
    package let interlockChapter: String

    package init(
        phraseIndex: Int,
        phraseKind: String,
        absoluteBar: Int,
        barIndexInPhrase: Int,
        interlockChapter: String
    ) {
        self.phraseIndex = phraseIndex
        self.phraseKind = phraseKind
        self.absoluteBar = absoluteBar
        self.barIndexInPhrase = barIndexInPhrase
        self.interlockChapter = interlockChapter
    }
}

package struct PCMSectionBoundaryBarMetrics: Codable, Equatable, Sendable {
    package let combinedRMSDBFS: Double
    package let crestFactor: Double
    package let bandShares: [Double]
    package let sideEnergyShare: Double?
    package let onsetCount: Int
    package let restOccupancy: Double

    package init(
        combinedRMSDBFS: Double,
        crestFactor: Double,
        bandShares: [Double],
        sideEnergyShare: Double?,
        onsetCount: Int,
        restOccupancy: Double
    ) {
        self.combinedRMSDBFS = combinedRMSDBFS
        self.crestFactor = crestFactor
        self.bandShares = bandShares
        self.sideEnergyShare = sideEnergyShare
        self.onsetCount = onsetCount
        self.restOccupancy = restOccupancy
    }

    private enum CodingKeys: String, CodingKey {
        case combinedRMSDBFS
        case crestFactor
        case bandShares
        case sideEnergyShare
        case onsetCount
        case restOccupancy
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(combinedRMSDBFS, forKey: .combinedRMSDBFS)
        try container.encode(crestFactor, forKey: .crestFactor)
        try container.encode(bandShares, forKey: .bandShares)
        if let sideEnergyShare {
            try container.encode(sideEnergyShare, forKey: .sideEnergyShare)
        } else {
            try container.encodeNil(forKey: .sideEnergyShare)
        }
        try container.encode(onsetCount, forKey: .onsetCount)
        try container.encode(restOccupancy, forKey: .restOccupancy)
    }
}

package struct PCMSectionBoundaryTransitionCell:
    Codable, Equatable, Sendable {
    package let index: Int
    package let startFrame: Int
    package let frameCount: Int
    package let sourceRMSDBFS: Double
    package let bandShares: [Double]
    package let onsetCount: Int

    package init(
        index: Int,
        startFrame: Int,
        frameCount: Int,
        sourceRMSDBFS: Double,
        bandShares: [Double],
        onsetCount: Int
    ) {
        self.index = index
        self.startFrame = startFrame
        self.frameCount = frameCount
        self.sourceRMSDBFS = sourceRMSDBFS
        self.bandShares = bandShares
        self.onsetCount = onsetCount
    }
}

package struct PCMSectionBoundaryBarObservation:
    Codable, Equatable, Sendable {
    package let timelineIndex: Int
    package let startFrame: Int
    package let frameCount: Int
    package let score: PCMSectionBoundaryScoreBar
    package let metrics: PCMSectionBoundaryBarMetrics
    package let transitionCells: [PCMSectionBoundaryTransitionCell]

    package init(
        timelineIndex: Int,
        startFrame: Int,
        frameCount: Int,
        score: PCMSectionBoundaryScoreBar,
        metrics: PCMSectionBoundaryBarMetrics,
        transitionCells: [PCMSectionBoundaryTransitionCell]
    ) {
        self.timelineIndex = timelineIndex
        self.startFrame = startFrame
        self.frameCount = frameCount
        self.score = score
        self.metrics = metrics
        self.transitionCells = transitionCells
    }
}

package struct PCMSectionBoundaryTimelineInput:
    Codable, Equatable, Sendable {
    package let sampleRate: Int
    package let sourceChannelCount: Int
    package let barFrameCount: Int
    package let focusPhraseIndex: Int
    package let bars: [PCMSectionBoundaryBarObservation]

    package init(
        sampleRate: Int,
        sourceChannelCount: Int,
        barFrameCount: Int,
        focusPhraseIndex: Int,
        bars: [PCMSectionBoundaryBarObservation]
    ) {
        self.sampleRate = sampleRate
        self.sourceChannelCount = sourceChannelCount
        self.barFrameCount = barFrameCount
        self.focusPhraseIndex = focusPhraseIndex
        self.bars = bars
    }
}

package struct PCMSectionBoundaryRecoveryTiming:
    Codable, Equatable, Sendable {
    package let barOffset: Int
    package let frameOffset: Int
    package let seconds: Double
}

package struct PCMSectionBoundaryMetricEvidence:
    Codable, Equatable, Sendable {
    package let name: String
    package let unit: String
    package let referenceMinimum: Double?
    package let referenceMaximum: Double?
    package let referenceMean: Double?
    package let transitionValue: Double?
    package let signedTransitionDelta: Double?
    package let absoluteTransitionDelta: Double?
    package let postTrajectory: [Double?]
    package let firstTowardReference: PCMSectionBoundaryRecoveryTiming?
    package let firstReferenceEnvelopeEntry: PCMSectionBoundaryRecoveryTiming?
    package let firstSustainedReferenceEnvelopeResidence:
        PCMSectionBoundaryRecoveryTiming?
    package let status: PCMSectionBoundaryRecoveryStatus

    private enum CodingKeys: String, CodingKey {
        case name
        case unit
        case referenceMinimum
        case referenceMaximum
        case referenceMean
        case transitionValue
        case signedTransitionDelta
        case absoluteTransitionDelta
        case postTrajectory
        case firstTowardReference
        case firstReferenceEnvelopeEntry
        case firstSustainedReferenceEnvelopeResidence
        case status
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(unit, forKey: .unit)
        try encode(referenceMinimum, forKey: .referenceMinimum, into: &container)
        try encode(referenceMaximum, forKey: .referenceMaximum, into: &container)
        try encode(referenceMean, forKey: .referenceMean, into: &container)
        try encode(transitionValue, forKey: .transitionValue, into: &container)
        try encode(
            signedTransitionDelta,
            forKey: .signedTransitionDelta,
            into: &container
        )
        try encode(
            absoluteTransitionDelta,
            forKey: .absoluteTransitionDelta,
            into: &container
        )
        try container.encode(postTrajectory, forKey: .postTrajectory)
        try encode(
            firstTowardReference,
            forKey: .firstTowardReference,
            into: &container
        )
        try encode(
            firstReferenceEnvelopeEntry,
            forKey: .firstReferenceEnvelopeEntry,
            into: &container
        )
        try encode(
            firstSustainedReferenceEnvelopeResidence,
            forKey: .firstSustainedReferenceEnvelopeResidence,
            into: &container
        )
        try container.encode(status, forKey: .status)
    }

    private func encode<T: Encodable>(
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

package struct PCMSectionBoundaryEvidence: Codable, Equatable, Sendable {
    package let index: Int
    package let timelineBarIndex: Int
    package let sampleFrame: Int
    package let markers: [PCMSectionBoundaryMarkerKind]
    package let previousScore: PCMSectionBoundaryScoreBar?
    package let currentScore: PCMSectionBoundaryScoreBar
    package let referenceBarIndices: [Int]
    package let postBarIndices: [Int]
    package let referenceComplete: Bool
    package let postHorizonComplete: Bool
    package let transitionCells: [PCMSectionBoundaryTransitionCell]
    package let metrics: [PCMSectionBoundaryMetricEvidence]
    package let jointRecoveryStatus: PCMSectionBoundaryRecoveryStatus

    private enum CodingKeys: String, CodingKey {
        case index
        case timelineBarIndex
        case sampleFrame
        case markers
        case previousScore
        case currentScore
        case referenceBarIndices
        case postBarIndices
        case referenceComplete
        case postHorizonComplete
        case transitionCells
        case metrics
        case jointRecoveryStatus
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(timelineBarIndex, forKey: .timelineBarIndex)
        try container.encode(sampleFrame, forKey: .sampleFrame)
        try container.encode(markers, forKey: .markers)
        if let previousScore {
            try container.encode(previousScore, forKey: .previousScore)
        } else {
            try container.encodeNil(forKey: .previousScore)
        }
        try container.encode(currentScore, forKey: .currentScore)
        try container.encode(referenceBarIndices, forKey: .referenceBarIndices)
        try container.encode(postBarIndices, forKey: .postBarIndices)
        try container.encode(referenceComplete, forKey: .referenceComplete)
        try container.encode(postHorizonComplete, forKey: .postHorizonComplete)
        try container.encode(transitionCells, forKey: .transitionCells)
        try container.encode(metrics, forKey: .metrics)
        try container.encode(jointRecoveryStatus, forKey: .jointRecoveryStatus)
    }
}

package struct PCMSectionBoundaryBaselineEvidence:
    Codable, Equatable, Sendable {
    package let schema: String
    package let analyzerVersion: String
    package let referenceBarCount: Int
    package let postHorizonBarCount: Int
    package let transitionCellCount: Int
    package let metricOrder: [String]
    package let input: PCMSectionBoundaryTimelineInput
    package let boundaries: [PCMSectionBoundaryEvidence]
}

/// Detached score-to-PCM boundary evidence. The builder composes existing PCM
/// observation authorities; the pure timeline analyzer derives no musical
/// decisions and does not discover boundaries from audio.
package enum PCMSectionBoundaryBaselineAnalyzer {
    package static let schema = "autotechno-pcm-section-boundary-baseline.v1"
    package static let analyzerVersion =
        "autotechno-pcm-section-boundary-baseline-analyzer.v1"
    package static let referenceBarCount = 2
    package static let postHorizonBarCount = 8
    package static let transitionCellCount = 16
    package static let maximumPhraseCount = 3
    package static let maximumBarCount = 48
    package static let metricOrder = [
        "combined-rms-dbfs",
        "crest-factor",
        "sub-band-share",
        "low-mid-band-share",
        "mid-band-share",
        "high-band-share",
        "full-band-side-energy-share",
        "onset-count",
        "rest-occupancy",
    ]
    package static let metricUnits = [
        "dBFS", "ratio", "share", "share", "share", "share", "share",
        "count", "share",
    ]
    package static let boundaryMarkerOrder =
        PCMSectionBoundaryMarkerKind.allCases
    package static let recoveryDefinition =
        "two-bar-closed-envelope-two-consecutive-post-bars"

    package static func makeInput(
        channels: [[Float]],
        sampleRate: Double,
        scoreBars: [PCMSectionBoundaryScoreBar],
        focusPhraseIndex: Int
    ) -> PCMSectionBoundaryTimelineInput? {
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
        let barFrameCount = Int((sampleRate * 240 / 130).rounded())
        guard barFrameCount > 0,
              frameCount == scoreBars.count * barFrameCount,
              !scoreBars.isEmpty,
              scoreBars.count <= maximumBarCount,
              let signal = PCMSignalIntegrityAnalyzer.analyze(
                channels: channels,
                sampleRate: sampleRate,
                segmentFrameCount: barFrameCount
              ),
              let spectral = PCMSpectralBaselineAnalyzer.analyze(
                channels: channels,
                sampleRate: sampleRate,
                segmentFrameCount: barFrameCount
              ),
              let stereo = PCMStereoCompatibilityAnalyzer.analyze(
                channels: channels,
                sampleRate: sampleRate,
                segmentFrameCount: barFrameCount
              ),
              let rhythmic = PCMRhythmicBaselineAnalyzer.analyze(
                channels: channels,
                sampleRate: sampleRate
              ),
              signal.segments.count == scoreBars.count,
              spectral.segments.count == scoreBars.count,
              stereo.segments.count == scoreBars.count,
              rhythmic.bars.count == scoreBars.count else {
            return nil
        }

        var bars: [PCMSectionBoundaryBarObservation] = []
        bars.reserveCapacity(scoreBars.count)
        for index in scoreBars.indices {
            let signalBar = signal.segments[index]
            let spectralBar = spectral.segments[index]
            let stereoBar = stereo.segments[index]
            let rhythmicBar = rhythmic.bars[index]
            guard signalBar.frameCount == barFrameCount,
                  spectralBar.frameCount == barFrameCount,
                  stereoBar.frameCount == barFrameCount,
                  rhythmicBar.complete,
                  spectralBar.summary.bandShares.count == 4,
                  spectralBar.windows.count == transitionCellCount,
                  rhythmicBar.gridOnsetCounts.count == transitionCellCount,
                  let rms = signalBar.combined.rms,
                  let rmsDBFS = PCMSignalIntegrityAnalyzer.decibels(
                    amplitude: rms
                  ),
                  let crest = signalBar.combined.crestFactor,
                  let fullStereo = stereoBar.domains.first(where: {
                    $0.name == "full"
                  }) else {
                return nil
            }
            let cells = zip(
                spectralBar.windows,
                rhythmicBar.gridOnsetCounts
            ).map { window, onsetCount in
                PCMSectionBoundaryTransitionCell(
                    index: window.index,
                    startFrame: index * barFrameCount + window.cellStartFrame,
                    frameCount: window.cellFrameCount,
                    sourceRMSDBFS: window.sourceRMSDBFS,
                    bandShares: window.bandShares,
                    onsetCount: onsetCount
                )
            }
            bars.append(PCMSectionBoundaryBarObservation(
                timelineIndex: index,
                startFrame: index * barFrameCount,
                frameCount: barFrameCount,
                score: scoreBars[index],
                metrics: PCMSectionBoundaryBarMetrics(
                    combinedRMSDBFS: rmsDBFS,
                    crestFactor: crest,
                    bandShares: spectralBar.summary.bandShares,
                    sideEnergyShare: fullStereo.sideEnergyShare,
                    onsetCount: rhythmicBar.onsetCount,
                    restOccupancy: rhythmicBar.restOccupancy
                ),
                transitionCells: cells
            ))
        }
        let input = PCMSectionBoundaryTimelineInput(
            sampleRate: Int(sampleRate),
            sourceChannelCount: channels.count,
            barFrameCount: barFrameCount,
            focusPhraseIndex: focusPhraseIndex,
            bars: bars
        )
        return validate(input) ? input : nil
    }

    package static func analyze(
        input: PCMSectionBoundaryTimelineInput
    ) -> PCMSectionBoundaryBaselineEvidence? {
        guard validate(input) else { return nil }
        var boundaries: [PCMSectionBoundaryEvidence] = []
        for index in input.bars.indices {
            let current = input.bars[index]
            let previous = index > 0 ? input.bars[index - 1] : nil
            var markers: [PCMSectionBoundaryMarkerKind] = []
            if current.score.absoluteBar == 0 { markers.append(.sessionStart) }
            if current.score.barIndexInPhrase == 0 { markers.append(.phraseStart) }
            if let previous,
               previous.score.phraseKind != current.score.phraseKind {
                markers.append(.phraseKindChange)
            }
            if let previous,
               previous.score.interlockChapter != current.score.interlockChapter {
                markers.append(.interlockChapterChange)
            }
            guard !markers.isEmpty else { continue }
            let touchesFocus = current.score.phraseIndex == input.focusPhraseIndex ||
                previous?.score.phraseIndex == input.focusPhraseIndex
            guard touchesFocus else { continue }

            let referenceStart = max(0, index - referenceBarCount)
            let referenceIndices = Array(referenceStart..<index)
            let postEnd = min(input.bars.count, index + postHorizonBarCount)
            let postIndices = Array(index..<postEnd)
            let referenceComplete = referenceIndices.count == referenceBarCount
            let postComplete = postIndices.count == postHorizonBarCount
            let metricEvidence = metricOrder.indices.map { metricIndex in
                analyzeMetric(
                    index: metricIndex,
                    input: input,
                    referenceIndices: referenceIndices,
                    postIndices: postIndices,
                    referenceComplete: referenceComplete,
                    postComplete: postComplete
                )
            }
            boundaries.append(PCMSectionBoundaryEvidence(
                index: boundaries.count,
                timelineBarIndex: index,
                sampleFrame: current.startFrame,
                markers: markers,
                previousScore: previous?.score,
                currentScore: current.score,
                referenceBarIndices: referenceIndices,
                postBarIndices: postIndices,
                referenceComplete: referenceComplete,
                postHorizonComplete: postComplete,
                transitionCells: current.transitionCells,
                metrics: metricEvidence,
                jointRecoveryStatus: jointStatus(metricEvidence)
            ))
        }
        return PCMSectionBoundaryBaselineEvidence(
            schema: schema,
            analyzerVersion: analyzerVersion,
            referenceBarCount: referenceBarCount,
            postHorizonBarCount: postHorizonBarCount,
            transitionCellCount: transitionCellCount,
            metricOrder: metricOrder,
            input: input,
            boundaries: boundaries
        )
    }

    private static func analyzeMetric(
        index: Int,
        input: PCMSectionBoundaryTimelineInput,
        referenceIndices: [Int],
        postIndices: [Int],
        referenceComplete: Bool,
        postComplete: Bool
    ) -> PCMSectionBoundaryMetricEvidence {
        let references = referenceIndices.map {
            value(index: index, metrics: input.bars[$0].metrics)
        }
        let post = postIndices.map {
            value(index: index, metrics: input.bars[$0].metrics)
        }
        var status: PCMSectionBoundaryRecoveryStatus =
            .notObservedWithinHorizon
        var minimum: Double?
        var maximum: Double?
        var mean: Double?
        var transition: Double?
        var signedDelta: Double?
        var absoluteDelta: Double?
        var toward: PCMSectionBoundaryRecoveryTiming?
        var entry: PCMSectionBoundaryRecoveryTiming?
        var sustained: PCMSectionBoundaryRecoveryTiming?

        if !referenceComplete {
            status = .missingReference
        } else if !postComplete {
            status = .missingPost
        } else if references.contains(where: { $0 == nil }) ||
                    post.contains(where: { $0 == nil }) {
            status = .missingMetric
        } else {
            let referenceValues = references.compactMap { $0 }
            let postValues = post.compactMap { $0 }
            minimum = referenceValues.min()
            maximum = referenceValues.max()
            mean = referenceValues.reduce(0, +) / Double(referenceValues.count)
            transition = postValues.first
            if let mean, let transition {
                signedDelta = transition - mean
                absoluteDelta = abs(transition - mean)
                var previousDistance = abs(referenceValues.last! - mean)
                for offset in postValues.indices {
                    let distance = abs(postValues[offset] - mean)
                    if toward == nil && distance < previousDistance {
                        toward = timing(offset: offset, input: input)
                    }
                    previousDistance = distance
                    if entry == nil,
                       postValues[offset] >= minimum!,
                       postValues[offset] <= maximum! {
                        entry = timing(offset: offset, input: input)
                    }
                    if offset + 1 < postValues.count,
                       postValues[offset] >= minimum!,
                       postValues[offset] <= maximum!,
                       postValues[offset + 1] >= minimum!,
                       postValues[offset + 1] <= maximum! {
                        sustained = timing(offset: offset, input: input)
                        status = .sustainedObserved
                        break
                    }
                }
            }
        }
        if referenceComplete {
            let available = references.compactMap { $0 }
            if available.count == references.count {
                minimum = available.min()
                maximum = available.max()
                mean = available.reduce(0, +) / Double(available.count)
            }
        }
        transition = post.first ?? nil
        if let mean, let transition {
            signedDelta = transition - mean
            absoluteDelta = abs(signedDelta!)
        }
        return PCMSectionBoundaryMetricEvidence(
            name: metricOrder[index],
            unit: metricUnits[index],
            referenceMinimum: minimum,
            referenceMaximum: maximum,
            referenceMean: mean,
            transitionValue: transition,
            signedTransitionDelta: signedDelta,
            absoluteTransitionDelta: absoluteDelta,
            postTrajectory: post,
            firstTowardReference: toward,
            firstReferenceEnvelopeEntry: entry,
            firstSustainedReferenceEnvelopeResidence: sustained,
            status: status
        )
    }

    private static func timing(
        offset: Int,
        input: PCMSectionBoundaryTimelineInput
    ) -> PCMSectionBoundaryRecoveryTiming {
        let frames = offset * input.barFrameCount
        return PCMSectionBoundaryRecoveryTiming(
            barOffset: offset,
            frameOffset: frames,
            seconds: Double(frames) / Double(input.sampleRate)
        )
    }

    private static func jointStatus(
        _ metrics: [PCMSectionBoundaryMetricEvidence]
    ) -> PCMSectionBoundaryRecoveryStatus {
        if metrics.allSatisfy({ $0.status == .sustainedObserved }) {
            return .sustainedObserved
        }
        for unavailable in [
            PCMSectionBoundaryRecoveryStatus.missingReference,
            .missingPost,
            .missingMetric,
        ] where metrics.contains(where: { $0.status == unavailable }) {
            return unavailable
        }
        return .notObservedWithinHorizon
    }

    private static func value(
        index: Int,
        metrics: PCMSectionBoundaryBarMetrics
    ) -> Double? {
        switch index {
        case 0: metrics.combinedRMSDBFS
        case 1: metrics.crestFactor
        case 2...5: metrics.bandShares[index - 2]
        case 6: metrics.sideEnergyShare
        case 7: Double(metrics.onsetCount)
        case 8: metrics.restOccupancy
        default: nil
        }
    }

    private static func validate(
        _ input: PCMSectionBoundaryTimelineInput
    ) -> Bool {
        guard input.sampleRate > 0,
              (input.sourceChannelCount == 1 || input.sourceChannelCount == 2),
              input.barFrameCount == Int(
                (Double(input.sampleRate) * 240 / 130).rounded()
              ),
              !input.bars.isEmpty,
              input.bars.count <= maximumBarCount,
              input.bars.contains(where: {
                $0.score.phraseIndex == input.focusPhraseIndex
              }) else {
            return false
        }
        let phraseIndices = input.bars.map(\.score.phraseIndex)
        let distinctPhrases = Array(Set(phraseIndices)).sorted()
        guard distinctPhrases.count <= maximumPhraseCount,
              zip(distinctPhrases, distinctPhrases.dropFirst()).allSatisfy({
                $0.1 == $0.0 + 1
              }) else {
            return false
        }
        for index in input.bars.indices {
            let bar = input.bars[index]
            let metrics = bar.metrics
            guard bar.timelineIndex == index,
                  bar.startFrame == index * input.barFrameCount,
                  bar.frameCount == input.barFrameCount,
                  bar.score.phraseIndex >= 0,
                  !bar.score.phraseKind.isEmpty,
                  bar.score.absoluteBar >= 0,
                  bar.score.barIndexInPhrase >= 0,
                  !bar.score.interlockChapter.isEmpty,
                  metrics.combinedRMSDBFS.isFinite,
                  metrics.crestFactor.isFinite,
                  metrics.crestFactor >= 0,
                  metrics.bandShares.count == 4,
                  metrics.bandShares.allSatisfy({
                    $0.isFinite && $0 >= 0 && $0 <= 1
                  }),
                  metrics.sideEnergyShare.map({
                    $0.isFinite && $0 >= 0 && $0 <= 1
                  }) ?? true,
                  metrics.onsetCount >= 0,
                  metrics.restOccupancy.isFinite,
                  metrics.restOccupancy >= 0,
                  metrics.restOccupancy <= 1,
                  bar.transitionCells.count == transitionCellCount else {
                return false
            }
            var cellEnd = bar.startFrame
            for cellIndex in bar.transitionCells.indices {
                let cell = bar.transitionCells[cellIndex]
                guard cell.index == cellIndex,
                      cell.startFrame == cellEnd,
                      cell.frameCount > 0,
                      cell.sourceRMSDBFS.isFinite,
                      cell.bandShares.count == 4,
                      cell.bandShares.allSatisfy({
                        $0.isFinite && $0 >= 0 && $0 <= 1
                      }),
                      cell.onsetCount >= 0 else {
                    return false
                }
                cellEnd += cell.frameCount
            }
            guard cellEnd == bar.startFrame + bar.frameCount else { return false }
            if index > 0 {
                let previous = input.bars[index - 1].score
                guard bar.score.absoluteBar == previous.absoluteBar + 1 else {
                    return false
                }
                if bar.score.phraseIndex == previous.phraseIndex {
                    guard bar.score.barIndexInPhrase ==
                        previous.barIndexInPhrase + 1,
                          bar.score.phraseKind == previous.phraseKind else {
                        return false
                    }
                } else {
                    guard bar.score.phraseIndex == previous.phraseIndex + 1,
                          bar.score.barIndexInPhrase == 0 else {
                        return false
                    }
                }
            }
        }
        return true
    }
}
