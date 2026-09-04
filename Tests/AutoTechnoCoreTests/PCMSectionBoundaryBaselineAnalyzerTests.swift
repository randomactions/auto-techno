@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("PCM section-boundary baseline analyzer")
struct PCMSectionBoundaryBaselineAnalyzerTests {
    @Test("Score markers merge in fixed order and remain focus bounded")
    func markersAndFocusBounds() throws {
        let evidence = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: input(sampleRate: 48_000, totalBars: 22)
            )
        )
        #expect(evidence.boundaries.map(\.timelineBarIndex) == [4, 8, 14])
        #expect(evidence.boundaries[0].markers == [
            .phraseStart, .phraseKindChange,
        ])
        #expect(evidence.boundaries[1].markers == [
            .interlockChapterChange,
        ])
        #expect(evidence.boundaries[2].markers == [
            .phraseStart, .phraseKindChange, .interlockChapterChange,
        ])
        #expect(evidence.boundaries[0].referenceBarIndices == [2, 3])
        #expect(evidence.boundaries[0].postBarIndices == Array(4..<12))
        #expect(evidence.boundaries[2].postBarIndices == Array(14..<22))
        #expect(evidence.boundaries.allSatisfy { $0.referenceComplete })
        #expect(evidence.boundaries.allSatisfy { $0.postHorizonComplete })
        #expect(evidence.boundaries[0].transitionCells.count == 16)
    }

    @Test("Recovery facts distinguish movement, entry, and sustained residence")
    func recoveryFacts() throws {
        var values = [Double](repeating: 10, count: 22)
        values.replaceSubrange(4..<12, with: [20, 18, 14, 10, 10, 10, 10, 10])
        let evidence = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: input(sampleRate: 48_000, totalBars: 22, rms: values)
            )
        )
        let metric = evidence.boundaries[0].metrics[0]
        #expect(metric.referenceMinimum == 10)
        #expect(metric.referenceMaximum == 10)
        #expect(metric.referenceMean == 10)
        #expect(metric.transitionValue == 20)
        #expect(metric.signedTransitionDelta == 10)
        #expect(metric.absoluteTransitionDelta == 10)
        #expect(metric.firstTowardReference?.barOffset == 1)
        #expect(metric.firstReferenceEnvelopeEntry?.barOffset == 3)
        #expect(
            metric.firstSustainedReferenceEnvelopeResidence?.barOffset == 3
        )
        #expect(metric.status == .sustainedObserved)
        #expect(metric.firstTowardReference?.frameOffset == 88_615)
        #expect(metric.firstTowardReference?.seconds == 88_615.0 / 48_000.0)
    }

    @Test(arguments: [
        ([20.0, 20, 18, 14, 10, 10, 10, 10], 2, 4, 4),
        ([20.0, 5, 10, 10, 10, 10, 10, 10], 1, 2, 2),
    ])
    func delayedAndOvershootRecovery(
        post: [Double],
        toward: Int,
        entry: Int,
        sustained: Int
    ) throws {
        var values = [Double](repeating: 10, count: 22)
        values.replaceSubrange(4..<12, with: post)
        let metric = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: input(sampleRate: 44_100, totalBars: 22, rms: values)
            )
        ).boundaries[0].metrics[0]
        #expect(metric.firstTowardReference?.barOffset == toward)
        #expect(metric.firstReferenceEnvelopeEntry?.barOffset == entry)
        #expect(
            metric.firstSustainedReferenceEnvelopeResidence?.barOffset == sustained
        )
    }

    @Test(arguments: [
        [20.0, 20, 20, 20, 20, 20, 20, 20],
        [20.0, 10, 20, 10, 20, 10, 20, 10],
    ])
    func nonReturnAndOscillationRemainUnresolved(post: [Double]) throws {
        var values = [Double](repeating: 10, count: 22)
        values.replaceSubrange(4..<12, with: post)
        let metric = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: input(sampleRate: 48_000, totalBars: 22, rms: values)
            )
        ).boundaries[0].metrics[0]
        #expect(metric.status == .notObservedWithinHorizon)
        #expect(metric.firstSustainedReferenceEnvelopeResidence == nil)
    }

    @Test("Transition cells retain abrupt, ramped, and delayed consequences")
    func transitionCellsRemainRaw() throws {
        var bars = input(sampleRate: 48_000, totalBars: 22).bars
        let source = bars[4]
        let ramp = source.transitionCells.map { cell in
            PCMSectionBoundaryTransitionCell(
                index: cell.index,
                startFrame: cell.startFrame,
                frameCount: cell.frameCount,
                sourceRMSDBFS: -60 + Double(cell.index) * 2,
                bandShares: cell.bandShares,
                onsetCount: cell.index < 8 ? 0 : 1
            )
        }
        bars[4] = PCMSectionBoundaryBarObservation(
            timelineIndex: source.timelineIndex,
            startFrame: source.startFrame,
            frameCount: source.frameCount,
            score: source.score,
            metrics: source.metrics,
            transitionCells: ramp
        )
        let altered = PCMSectionBoundaryTimelineInput(
            sampleRate: 48_000,
            sourceChannelCount: 2,
            barFrameCount: bars[0].frameCount,
            focusPhraseIndex: 1,
            bars: bars
        )
        let evidence = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(input: altered)
        )
        let cells = evidence.boundaries[0].transitionCells
        #expect(cells.first?.sourceRMSDBFS == -60)
        #expect(cells.last?.sourceRMSDBFS == -30)
        #expect(cells.prefix(8).allSatisfy { $0.onsetCount == 0 })
        #expect(cells.suffix(8).allSatisfy { $0.onsetCount == 1 })
    }

    @Test("Session start and truncated follow-through fail closed explicitly")
    func partialContext() throws {
        let startEvidence = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: input(
                    sampleRate: 48_000,
                    totalBars: 22,
                    focusPhraseIndex: 0
                )
            )
        )
        let start = try #require(startEvidence.boundaries.first)
        #expect(start.timelineBarIndex == 0)
        #expect(start.markers == [.sessionStart, .phraseStart])
        #expect(start.referenceComplete == false)
        #expect(start.jointRecoveryStatus == .missingReference)

        let endEvidence = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: input(sampleRate: 48_000, totalBars: 18)
            )
        )
        let outgoing = try #require(
            endEvidence.boundaries.first { $0.timelineBarIndex == 14 }
        )
        #expect(outgoing.postHorizonComplete == false)
        #expect(outgoing.jointRecoveryStatus == .missingPost)
    }

    @Test("Unavailable spatial evidence is explicit and blocks joint recovery")
    func missingSpatialMetric() throws {
        var bars = input(sampleRate: 48_000, totalBars: 22).bars
        for index in bars.indices {
            let source = bars[index]
            bars[index] = replacingMetrics(
                source,
                PCMSectionBoundaryBarMetrics(
                    combinedRMSDBFS: source.metrics.combinedRMSDBFS,
                    crestFactor: source.metrics.crestFactor,
                    bandShares: source.metrics.bandShares,
                    sideEnergyShare: nil,
                    onsetCount: source.metrics.onsetCount,
                    restOccupancy: source.metrics.restOccupancy
                )
            )
        }
        let evidence = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: PCMSectionBoundaryTimelineInput(
                    sampleRate: 48_000,
                    sourceChannelCount: 2,
                    barFrameCount: bars[0].frameCount,
                    focusPhraseIndex: 1,
                    bars: bars
                )
            )
        )
        let boundary = evidence.boundaries[0]
        #expect(boundary.metrics[6].status == .missingMetric)
        #expect(boundary.jointRecoveryStatus == .missingMetric)
    }

    @Test("Physical bar timing is rate normalized")
    func sampleRateNormalization() throws {
        let at44 = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: input(sampleRate: 44_100, totalBars: 22)
            )
        )
        let at48 = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: input(sampleRate: 48_000, totalBars: 22)
            )
        )
        #expect(at44.input.barFrameCount == 81_415)
        #expect(at48.input.barFrameCount == 88_615)
        let seconds44 = Double(at44.input.barFrameCount) / 44_100
        let seconds48 = Double(at48.input.barFrameCount) / 48_000
        #expect(abs(seconds44 - seconds48) < 0.000_02)
    }

    @Test("Explicit nullable fields encode as JSON null")
    func explicitNullEncoding() throws {
        var bars = input(sampleRate: 48_000, totalBars: 22).bars
        bars[0] = replacingMetrics(
            bars[0],
            PCMSectionBoundaryBarMetrics(
                combinedRMSDBFS: 10,
                crestFactor: 2,
                bandShares: [0.25, 0.25, 0.25, 0.25],
                sideEnergyShare: nil,
                onsetCount: 4,
                restOccupancy: 0.75
            )
        )
        let evidence = try #require(
            PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: PCMSectionBoundaryTimelineInput(
                    sampleRate: 48_000,
                    sourceChannelCount: 2,
                    barFrameCount: bars[0].frameCount,
                    focusPhraseIndex: 0,
                    bars: bars
                )
            )
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(evidence))
                as? [String: Any]
        )
        let inputObject = try #require(object["input"] as? [String: Any])
        let jsonBars = try #require(inputObject["bars"] as? [[String: Any]])
        let metrics = try #require(jsonBars[0]["metrics"] as? [String: Any])
        #expect(metrics.keys.contains("sideEnergyShare"))
        #expect(metrics["sideEnergyShare"] is NSNull)
        let boundaries = try #require(
            object["boundaries"] as? [[String: Any]]
        )
        #expect(boundaries[0].keys.contains("previousScore"))
        #expect(boundaries[0]["previousScore"] is NSNull)
    }

    @Test("Exact PCM builder composes established analyzers")
    func exactPCMBuilder() throws {
        let sampleRate = 8_000
        let barFrames = Int((Double(sampleRate) * 240 / 130).rounded())
        let score = (0..<10).map { index in
            PCMSectionBoundaryScoreBar(
                phraseIndex: 0,
                phraseKind: "lock",
                absoluteBar: index,
                barIndexInPhrase: index,
                interlockChapter: index < 4 ? "home" : "motion"
            )
        }
        let mono = (0..<(barFrames * score.count)).map { frame in
            Float(0.1 * sin(2 * Double.pi * 110 * Double(frame) /
                Double(sampleRate)))
        }
        let built = try #require(
            PCMSectionBoundaryBaselineAnalyzer.makeInput(
                channels: [mono, mono],
                sampleRate: Double(sampleRate),
                scoreBars: score,
                focusPhraseIndex: 0
            )
        )
        #expect(built.bars.count == 10)
        #expect(built.bars.allSatisfy { $0.transitionCells.count == 16 })
        #expect(built.bars.allSatisfy { $0.metrics.bandShares.count == 4 })
        #expect(
            PCMSectionBoundaryBaselineAnalyzer.analyze(input: built)?
                .boundaries.map(\.timelineBarIndex) == [0, 4]
        )
    }

    @Test("Malformed and discontinuous journeys are rejected")
    func rejectsMalformedInput() {
        let valid = input(sampleRate: 48_000, totalBars: 22)
        var bars = valid.bars
        let source = bars[5]
        bars[5] = PCMSectionBoundaryBarObservation(
            timelineIndex: 5,
            startFrame: source.startFrame,
            frameCount: source.frameCount,
            score: PCMSectionBoundaryScoreBar(
                phraseIndex: source.score.phraseIndex,
                phraseKind: source.score.phraseKind,
                absoluteBar: source.score.absoluteBar + 1,
                barIndexInPhrase: source.score.barIndexInPhrase,
                interlockChapter: source.score.interlockChapter
            ),
            metrics: source.metrics,
            transitionCells: source.transitionCells
        )
        #expect(PCMSectionBoundaryBaselineAnalyzer.analyze(
            input: PCMSectionBoundaryTimelineInput(
                sampleRate: valid.sampleRate,
                sourceChannelCount: valid.sourceChannelCount,
                barFrameCount: valid.barFrameCount,
                focusPhraseIndex: valid.focusPhraseIndex,
                bars: bars
            )
        ) == nil)

        #expect(PCMSectionBoundaryBaselineAnalyzer.makeInput(
            channels: [[0, .nan]],
            sampleRate: 48_000,
            scoreBars: [],
            focusPhraseIndex: 0
        ) == nil)
    }

    private func input(
        sampleRate: Int,
        totalBars: Int,
        focusPhraseIndex: Int = 1,
        rms: [Double]? = nil
    ) -> PCMSectionBoundaryTimelineInput {
        let barFrames = Int((Double(sampleRate) * 240 / 130).rounded())
        let values = rms ?? [Double](repeating: 10, count: totalBars)
        let bars = (0..<totalBars).map { index -> PCMSectionBoundaryBarObservation in
            let phrase: Int
            let local: Int
            let kind: String
            let chapter: String
            if index < 4 {
                phrase = 0; local = index; kind = "lock"; chapter = "home"
            } else if index < 14 {
                phrase = 1; local = index - 4; kind = "contrast"
                chapter = index < 8 ? "home" : "motion"
            } else {
                phrase = 2; local = index - 14; kind = "identityReturn"
                chapter = "memory"
            }
            let start = index * barFrames
            let cells = (0..<16).map { cell -> PCMSectionBoundaryTransitionCell in
                let cellStart = start + cell * barFrames / 16
                let cellEnd = start + (cell + 1) * barFrames / 16
                return PCMSectionBoundaryTransitionCell(
                    index: cell,
                    startFrame: cellStart,
                    frameCount: cellEnd - cellStart,
                    sourceRMSDBFS: -18,
                    bandShares: [0.25, 0.25, 0.25, 0.25],
                    onsetCount: cell % 4 == 0 ? 1 : 0
                )
            }
            return PCMSectionBoundaryBarObservation(
                timelineIndex: index,
                startFrame: start,
                frameCount: barFrames,
                score: PCMSectionBoundaryScoreBar(
                    phraseIndex: phrase,
                    phraseKind: kind,
                    absoluteBar: index,
                    barIndexInPhrase: local,
                    interlockChapter: chapter
                ),
                metrics: PCMSectionBoundaryBarMetrics(
                    combinedRMSDBFS: values[index],
                    crestFactor: 2,
                    bandShares: [0.25, 0.25, 0.25, 0.25],
                    sideEnergyShare: 0.1,
                    onsetCount: 4,
                    restOccupancy: 0.75
                ),
                transitionCells: cells
            )
        }
        return PCMSectionBoundaryTimelineInput(
            sampleRate: sampleRate,
            sourceChannelCount: 2,
            barFrameCount: barFrames,
            focusPhraseIndex: focusPhraseIndex,
            bars: bars
        )
    }

    private func replacingMetrics(
        _ source: PCMSectionBoundaryBarObservation,
        _ metrics: PCMSectionBoundaryBarMetrics
    ) -> PCMSectionBoundaryBarObservation {
        PCMSectionBoundaryBarObservation(
            timelineIndex: source.timelineIndex,
            startFrame: source.startFrame,
            frameCount: source.frameCount,
            score: source.score,
            metrics: metrics,
            transitionCells: source.transitionCells
        )
    }
}
