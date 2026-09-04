import Foundation

package enum PCMKickFoundationCollisionClass: String, Codable, Sendable {
    case mutualSilence = "mutual-silence"
    case kickOnly = "kick-only"
    case foundationOnly = "foundation-only"
    case separated = "separated"
    case temporalOverlap = "temporal-overlap"
    case lowBandOverlap = "low-band-overlap"
}

package enum PCMKickFoundationPocketState: String, Codable, Sendable {
    case notAuthored = "not-authored"
    case exactSilence = "exact-silence"
}

package enum PCMKickFoundationCollisionUnavailableReason:
    String, Codable, Equatable, Sendable
{
    case unsupportedSampleRate = "unsupported-sample-rate"
    case emptySignal = "empty-signal"
    case unalignedSignals = "unaligned-signals"
    case nonFinitePCM = "non-finite-pcm"
    case duplicateEvent = "duplicate-event"
    case invalidEventGeometry = "invalid-event-geometry"
    case invalidPocketBinding = "invalid-pocket-binding"
    case insufficientAnalysisWindow = "insufficient-analysis-window"
    case canonicalBandEvidenceUnavailable = "canonical-band-evidence-unavailable"
}

/// Exact score/render binding supplied by the detached corpus exporter. Frames
/// are phrase-absolute so a pocket cannot be accidentally attached to another
/// bar or kick.
package struct PCMKickFoundationPocketInput: Equatable, Sendable {
    package let releaseStartFrame: Int
    package let releaseEndFrame: Int
    package let kickFrame: Int
    package let silenceFrameCount: Int
    package let silencePeak: Double
    package let silenceRMS: Double
    package let applied: Bool
    package let finite: Bool

    package init(
        releaseStartFrame: Int,
        releaseEndFrame: Int,
        kickFrame: Int,
        silenceFrameCount: Int,
        silencePeak: Double,
        silenceRMS: Double,
        applied: Bool,
        finite: Bool
    ) {
        self.releaseStartFrame = releaseStartFrame
        self.releaseEndFrame = releaseEndFrame
        self.kickFrame = kickFrame
        self.silenceFrameCount = silenceFrameCount
        self.silencePeak = silencePeak
        self.silenceRMS = silenceRMS
        self.applied = applied
        self.finite = finite
    }
}

/// One authoritative rendered kick event. `barStartFrame`, `barFrameCount`,
/// `step`, and `onsetFrame` are deliberately redundant: the analyzer rejects a
/// score event unless its integer rounding agrees with the rendered bar.
package struct PCMKickFoundationEventInput: Equatable, Sendable {
    package let id: String
    package let bar: Int
    package let step: Int
    package let barStartFrame: Int
    package let barFrameCount: Int
    package let onsetFrame: Int
    package let authoredFoundationRolesInBar: [String]
    package let pocket: PCMKickFoundationPocketInput?

    package init(
        id: String,
        bar: Int,
        step: Int,
        barStartFrame: Int,
        barFrameCount: Int,
        onsetFrame: Int,
        authoredFoundationRolesInBar: [String],
        pocket: PCMKickFoundationPocketInput? = nil
    ) {
        self.id = id
        self.bar = bar
        self.step = step
        self.barStartFrame = barStartFrame
        self.barFrameCount = barFrameCount
        self.onsetFrame = onsetFrame
        self.authoredFoundationRolesInBar = authoredFoundationRolesInBar
        self.pocket = pocket
    }
}

package struct PCMKickFoundationCollisionWindowEvidence:
    Codable, Equatable, Sendable
{
    package let index: Int
    package let startFrame: Int
    package let frameCount: Int
    package let kickMeanSquare: Double
    package let foundationMeanSquare: Double
    package let kickSubMeanSquare: Double
    package let foundationSubMeanSquare: Double
    package let kickActive: Bool
    package let foundationActive: Bool
    package let temporalOverlap: Bool
    package let subBandSimilarity: Double
    package let lowBandOverlap: Bool
}

package struct PCMKickFoundationCollisionEventEvidence:
    Codable, Equatable, Sendable
{
    package let id: String
    package let bar: Int
    package let step: Int
    package let onsetFrame: Int
    package let analysisEndFrame: Int
    package let analysisFrameCount: Int
    package let collisionClass: PCMKickFoundationCollisionClass
    package let responsibleSignals: [String]
    package let authoredFoundationRolesInBar: [String]
    package let pocketState: PCMKickFoundationPocketState
    package let pocketSilenceFrameCount: Int
    package let kickActiveWindowCount: Int
    package let foundationActiveWindowCount: Int
    package let temporalOverlapWindowCount: Int
    package let temporalOverlapFrameCount: Int
    package let temporalOverlapSeconds: Double
    package let longestTemporalOverlapFrameCount: Int
    package let lowBandOverlapWindowCount: Int
    package let lowBandOverlapFrameCount: Int
    package let lowBandOverlapSeconds: Double
    package let longestLowBandOverlapFrameCount: Int
    package let firstTemporalOverlapFrame: Int?
    package let lastTemporalOverlapEndFrame: Int?
    package let firstLowBandOverlapFrame: Int?
    package let lastLowBandOverlapEndFrame: Int?
    package let maximumSubBandSimilarity: Double
    package let kickOverFoundationDB: Double?
    package let durationResolutionMaximumFrames: Int
    package let confidence: String
    package let windows: [PCMKickFoundationCollisionWindowEvidence]
    package let finite: Bool
}

package struct PCMKickFoundationCollisionEvidence:
    Codable, Equatable, Sendable
{
    package let schema: String
    package let sampleRate: Int
    package let frameCount: Int
    package let kickSignal: String
    package let foundationSignal: String
    package let eventSource: String
    package let analysisWindow: String
    package let windowsPerEvent: Int
    package let activityMeanSquareThreshold: Double
    package let lowBand: MaskingBand
    package let lowBandOverlapThreshold: Double
    package let bandEnergyModel: String
    package let durationModel: String
    package let relativeEnergyUnit: String
    package let relativeEnergyInterpretation: String
    package let events: [PCMKickFoundationCollisionEventEvidence]
    package let finite: Bool
}

package enum PCMKickFoundationCollisionAnalysisResult: Equatable, Sendable {
    case available(PCMKickFoundationCollisionEvidence)
    case unavailable(PCMKickFoundationCollisionUnavailableReason)
}

/// Detached, descriptive kick/foundation reconciliation over exact local role
/// taps. It composes the canonical causal band-energy owner and authoritative
/// rendered kick events. It does not infer events, score quality, audibility,
/// masking severity, or a mix correction from PCM.
package enum PCMKickFoundationCollisionAnalyzer {
    package static let schema = "autotechno-pcm-kick-foundation-collision.v1"
    package static let analyzerVersion =
        "autotechno-pcm-kick-foundation-collision-analyzer.v1"
    package static let eventSource =
        "accepted-resolved-score-and-selected-candidate"
    package static let analysisWindow =
        "kick-onset-through-two-sixteenth-steps-bar-bounded"
    package static let durationModel =
        "sixteen-causal-cells-quantized-not-sample-exact"
    package static let bandEnergyModel =
        "causal-one-pole-difference-non-power-complementary-reset-at-event-onset"
    package static let relativeEnergyUnit = "kick-over-foundation-db-power-ratio"
    package static let relativeEnergyInterpretation =
        "descriptive-not-calibrated-not-excessive"
    package static let confidence =
        "exact-pcm-score-event-bound-causal-cell-quantized"
    package static let supportedSampleRates = [44_100, 48_000]
    package static let windowsPerEvent = SpectrumMaskingAnalyzer.analyzedWindowCount
    package static let activityMeanSquareThreshold =
        SpectrumMaskingAnalyzer.activeMeanSquareThreshold
    package static let lowBandOverlapThreshold =
        SpectrumMaskingAnalyzer.overlapThreshold

    package static func analyze(
        kick: [Float],
        foundation: [Float],
        sampleRate: Double,
        events: [PCMKickFoundationEventInput]
    ) -> PCMKickFoundationCollisionAnalysisResult {
        guard sampleRate.isFinite,
              sampleRate.rounded() == sampleRate,
              supportedSampleRates.contains(Int(sampleRate)) else {
            return .unavailable(.unsupportedSampleRate)
        }
        guard !kick.isEmpty, !foundation.isEmpty else {
            return .unavailable(.emptySignal)
        }
        guard kick.count == foundation.count else {
            return .unavailable(.unalignedSignals)
        }
        guard kick.allSatisfy(\.isFinite), foundation.allSatisfy(\.isFinite) else {
            return .unavailable(.nonFinitePCM)
        }
        let identifiers = events.map(\.id)
        let locations = events.map { "\($0.bar):\($0.step):\($0.onsetFrame)" }
        guard Set(identifiers).count == identifiers.count,
              Set(locations).count == locations.count else {
            return .unavailable(.duplicateEvent)
        }

        var eventEvidence: [PCMKickFoundationCollisionEventEvidence] = []
        eventEvidence.reserveCapacity(events.count)
        for event in events.sorted(by: eventOrder) {
            guard event.id.isEmpty == false,
                  event.bar >= 0,
                  (0..<16).contains(event.step),
                  event.barStartFrame >= 0,
                  event.barFrameCount >= windowsPerEvent,
                  event.barStartFrame <= kick.count - event.barFrameCount else {
                return .unavailable(.invalidEventGeometry)
            }
            let expectedOnset = event.barStartFrame + Int((
                Double(event.step) * Double(event.barFrameCount) / 16.0
            ).rounded())
            guard event.onsetFrame == expectedOnset,
                  event.onsetFrame >= event.barStartFrame,
                  event.onsetFrame < event.barStartFrame + event.barFrameCount else {
                return .unavailable(.invalidEventGeometry)
            }
            let twoSteps = Int((Double(event.barFrameCount) / 8.0).rounded())
            let analysisEnd = min(
                event.barStartFrame + event.barFrameCount,
                event.onsetFrame + twoSteps
            )
            let analysisFrames = analysisEnd - event.onsetFrame
            guard analysisFrames >= windowsPerEvent else {
                return .unavailable(.insufficientAnalysisWindow)
            }
            let kickSlice = Array(kick[event.onsetFrame..<analysisEnd])
            let foundationSlice = Array(
                foundation[event.onsetFrame..<analysisEnd]
            )
            guard let kickWindows = SpectrumMaskingAnalyzer.bandEnergyWindows(
                    kickSlice,
                    sampleRate: sampleRate
                  ),
                  let foundationWindows =
                    SpectrumMaskingAnalyzer.bandEnergyWindows(
                        foundationSlice,
                        sampleRate: sampleRate
                    ),
                  kickWindows.count == windowsPerEvent,
                  foundationWindows.count == windowsPerEvent else {
                return .unavailable(.canonicalBandEvidenceUnavailable)
            }
            let pocketState: PCMKickFoundationPocketState
            let pocketFrames: Int
            if let pocket = event.pocket {
                guard pocket.releaseStartFrame >= event.barStartFrame,
                      pocket.releaseStartFrame < pocket.releaseEndFrame,
                      pocket.releaseEndFrame < pocket.kickFrame,
                      pocket.kickFrame == event.onsetFrame,
                      pocket.silenceFrameCount ==
                        pocket.kickFrame - pocket.releaseEndFrame,
                      pocket.silenceFrameCount > 0,
                      pocket.silencePeak.bitPattern == 0,
                      pocket.silenceRMS.bitPattern == 0,
                      pocket.applied,
                      pocket.finite else {
                    return .unavailable(.invalidPocketBinding)
                }
                pocketState = .exactSilence
                pocketFrames = pocket.silenceFrameCount
            } else {
                pocketState = .notAuthored
                pocketFrames = 0
            }
            guard let reduced = reduce(
                event: event,
                analysisEnd: analysisEnd,
                sampleRate: sampleRate,
                pocketState: pocketState,
                pocketFrames: pocketFrames,
                kickWindows: kickWindows,
                foundationWindows: foundationWindows
            ) else {
                return .unavailable(.canonicalBandEvidenceUnavailable)
            }
            eventEvidence.append(reduced)
        }
        let finite = eventEvidence.allSatisfy(\.finite)
        guard finite else { return .unavailable(.canonicalBandEvidenceUnavailable) }
        return .available(PCMKickFoundationCollisionEvidence(
            schema: schema,
            sampleRate: Int(sampleRate),
            frameCount: kick.count,
            kickSignal: "kick",
            foundationSignal: "foundation",
            eventSource: eventSource,
            analysisWindow: analysisWindow,
            windowsPerEvent: windowsPerEvent,
            activityMeanSquareThreshold: activityMeanSquareThreshold,
            lowBand: SpectrumMaskingAnalyzer.bands[0],
            lowBandOverlapThreshold: lowBandOverlapThreshold,
            bandEnergyModel: bandEnergyModel,
            durationModel: durationModel,
            relativeEnergyUnit: relativeEnergyUnit,
            relativeEnergyInterpretation: relativeEnergyInterpretation,
            events: eventEvidence,
            finite: finite
        ))
    }

    private static func reduce(
        event: PCMKickFoundationEventInput,
        analysisEnd: Int,
        sampleRate: Double,
        pocketState: PCMKickFoundationPocketState,
        pocketFrames: Int,
        kickWindows: [MaskingBandEnergyWindow],
        foundationWindows: [MaskingBandEnergyWindow]
    ) -> PCMKickFoundationCollisionEventEvidence? {
        var windows: [PCMKickFoundationCollisionWindowEvidence] = []
        windows.reserveCapacity(windowsPerEvent)
        for index in 0..<windowsPerEvent {
            let kick = kickWindows[index]
            let foundation = foundationWindows[index]
            guard kick.index == index,
                  foundation.index == index,
                  kick.startFrame == foundation.startFrame,
                  kick.frameCount == foundation.frameCount,
                  kick.bandMeanSquares.count == SpectrumMaskingAnalyzer.bands.count,
                  foundation.bandMeanSquares.count ==
                    SpectrumMaskingAnalyzer.bands.count else {
                return nil
            }
            let kickActive = kick.sourceMeanSquare > activityMeanSquareThreshold
            let foundationActive = foundation.sourceMeanSquare >
                activityMeanSquareThreshold
            let temporalOverlap = kickActive && foundationActive
            let kickSub = kick.bandMeanSquares[0]
            let foundationSub = foundation.bandMeanSquares[0]
            let subPairActive = temporalOverlap &&
                kickSub > activityMeanSquareThreshold &&
                foundationSub > activityMeanSquareThreshold
            let similarity = subPairActive
                ? min(kickSub, foundationSub) / max(kickSub, foundationSub)
                : 0
            let lowOverlap = subPairActive &&
                similarity > lowBandOverlapThreshold
            let values = [
                kick.sourceMeanSquare, foundation.sourceMeanSquare,
                kickSub, foundationSub, similarity,
            ]
            guard values.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
                return nil
            }
            windows.append(PCMKickFoundationCollisionWindowEvidence(
                index: index,
                startFrame: event.onsetFrame + kick.startFrame,
                frameCount: kick.frameCount,
                kickMeanSquare: kick.sourceMeanSquare,
                foundationMeanSquare: foundation.sourceMeanSquare,
                kickSubMeanSquare: kickSub,
                foundationSubMeanSquare: foundationSub,
                kickActive: kickActive,
                foundationActive: foundationActive,
                temporalOverlap: temporalOverlap,
                subBandSimilarity: similarity,
                lowBandOverlap: lowOverlap
            ))
        }

        let kickActive = windows.filter(\.kickActive)
        let foundationActive = windows.filter(\.foundationActive)
        let temporal = windows.filter(\.temporalOverlap)
        let low = windows.filter(\.lowBandOverlap)
        let classification: PCMKickFoundationCollisionClass
        if kickActive.isEmpty && foundationActive.isEmpty {
            classification = .mutualSilence
        } else if foundationActive.isEmpty {
            classification = .kickOnly
        } else if kickActive.isEmpty {
            classification = .foundationOnly
        } else if temporal.isEmpty {
            classification = .separated
        } else if low.isEmpty {
            classification = .temporalOverlap
        } else {
            classification = .lowBandOverlap
        }
        let temporalFrames = temporal.reduce(0) { $0 + $1.frameCount }
        let lowFrames = low.reduce(0) { $0 + $1.frameCount }
        let temporalLongest = longestRunFrames(windows, keyPath: \.temporalOverlap)
        let lowLongest = longestRunFrames(windows, keyPath: \.lowBandOverlap)
        let kickPairEnergy = temporal.reduce(0.0) {
            $0 + $1.kickMeanSquare * Double($1.frameCount)
        }
        let foundationPairEnergy = temporal.reduce(0.0) {
            $0 + $1.foundationMeanSquare * Double($1.frameCount)
        }
        let relativeDB = kickPairEnergy > 0 && foundationPairEnergy > 0
            ? 10 * log10(kickPairEnergy / foundationPairEnergy) : nil
        let values: [Double] = [
            Double(temporalFrames) / sampleRate,
            Double(lowFrames) / sampleRate,
            windows.map(\.subBandSimilarity).max() ?? 0,
            relativeDB ?? 0,
        ]
        let finite = values.allSatisfy(\.isFinite)
        return PCMKickFoundationCollisionEventEvidence(
            id: event.id,
            bar: event.bar,
            step: event.step,
            onsetFrame: event.onsetFrame,
            analysisEndFrame: analysisEnd,
            analysisFrameCount: analysisEnd - event.onsetFrame,
            collisionClass: classification,
            responsibleSignals: ["kick", "foundation"],
            authoredFoundationRolesInBar:
                Array(Set(event.authoredFoundationRolesInBar)).sorted(),
            pocketState: pocketState,
            pocketSilenceFrameCount: pocketFrames,
            kickActiveWindowCount: kickActive.count,
            foundationActiveWindowCount: foundationActive.count,
            temporalOverlapWindowCount: temporal.count,
            temporalOverlapFrameCount: temporalFrames,
            temporalOverlapSeconds: Double(temporalFrames) / sampleRate,
            longestTemporalOverlapFrameCount: temporalLongest,
            lowBandOverlapWindowCount: low.count,
            lowBandOverlapFrameCount: lowFrames,
            lowBandOverlapSeconds: Double(lowFrames) / sampleRate,
            longestLowBandOverlapFrameCount: lowLongest,
            firstTemporalOverlapFrame: temporal.first?.startFrame,
            lastTemporalOverlapEndFrame: temporal.last.map {
                $0.startFrame + $0.frameCount
            },
            firstLowBandOverlapFrame: low.first?.startFrame,
            lastLowBandOverlapEndFrame: low.last.map {
                $0.startFrame + $0.frameCount
            },
            maximumSubBandSimilarity:
                windows.map(\.subBandSimilarity).max() ?? 0,
            kickOverFoundationDB: relativeDB,
            durationResolutionMaximumFrames:
                windows.map(\.frameCount).max() ?? 0,
            confidence: confidence,
            windows: windows,
            finite: finite
        )
    }

    private static func longestRunFrames(
        _ windows: [PCMKickFoundationCollisionWindowEvidence],
        keyPath: KeyPath<PCMKickFoundationCollisionWindowEvidence, Bool>
    ) -> Int {
        var current = 0
        var longest = 0
        for window in windows {
            if window[keyPath: keyPath] {
                current += window.frameCount
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private static func eventOrder(
        _ lhs: PCMKickFoundationEventInput,
        _ rhs: PCMKickFoundationEventInput
    ) -> Bool {
        if lhs.onsetFrame != rhs.onsetFrame {
            return lhs.onsetFrame < rhs.onsetFrame
        }
        return lhs.id < rhs.id
    }
}
