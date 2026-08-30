import Foundation

/// Perceptually distinct held materials inside the one canonical kick voice.
/// They are not genre presets or selectable instruments: the active
/// long-horizon episode moves the same kick identity between them.
package enum KickMorphologyHome: String, CaseIterable, Sendable {
    case balanced
    case relaxed
    case ghostSoft = "ghost-soft"
    case resonantAccent = "resonant-accent"
}

/// The already-owned episode coordinates needed to resolve one kick bar. This
/// is derived from `LongHorizonContinuationState`; it adds no second clock or
/// persistent controller.
package struct KickMorphologyEpisodeContext: Equatable, Sendable {
    package let episodeID: UInt64
    package let episodeIndex: Int
    package let operatorKind: LongHorizonEpisodeOperator
    package let startedAtPresentationBar: Int
    package let previousOperatorKind: LongHorizonEpisodeOperator?

    package init(
        episodeID: UInt64,
        episodeIndex: Int,
        operatorKind: LongHorizonEpisodeOperator,
        startedAtPresentationBar: Int,
        previousOperatorKind: LongHorizonEpisodeOperator?
    ) {
        self.episodeID = episodeID
        self.episodeIndex = max(0, episodeIndex)
        self.operatorKind = operatorKind
        self.startedAtPresentationBar = max(0, startedAtPresentationBar)
        self.previousOperatorKind = previousOperatorKind
    }

    package init(continuation: LongHorizonContinuationState) {
        self.init(
            episodeID: continuation.currentEpisode.id,
            episodeIndex: continuation.currentEpisode.episodeIndex,
            operatorKind: continuation.currentEpisode.operatorKind,
            startedAtPresentationBar: continuation.currentEpisode.startedAtBar,
            previousOperatorKind: continuation.recentEpisodes.last?.operatorKind
        )
    }
}

/// Complete bounded source parameters consumed by the existing kick renderer.
/// Keeping the values in Core makes the rendered change a score consequence
/// rather than a DSP-side musical decision.
package struct KickMorphologyParameters: Equatable, Sendable {
    package let fundamentalHz: Double
    package let pitchDepthHz: Double
    package let fastPitchDepthHz: Double
    package let pitchDecayPerSecond: Double
    package let fastPitchDecayPerSecond: Double
    package let bodyDecayPerSecond: Double
    package let subDecayPerSecond: Double
    package let secondHarmonicLevel: Double
    package let bodyDrive: Double
    package let subLevel: Double
    package let noiseClickLevel: Double
    package let tonalClickLevel: Double
    package let clickFrequencyHz: Double
    /// Authored source presence applied to the complete body + sub + click sum
    /// before source dynamics, detector, ducking, and audible mix routing.
    package let presenceScale: Double

    package func interpolated(
        to other: Self,
        progress requestedProgress: Double
    ) -> Self {
        let progress = min(1, max(0, requestedProgress))
        func value(_ start: Double, _ end: Double) -> Double {
            start + (end - start) * progress
        }
        return Self(
            fundamentalHz: value(fundamentalHz, other.fundamentalHz),
            pitchDepthHz: value(pitchDepthHz, other.pitchDepthHz),
            fastPitchDepthHz: value(fastPitchDepthHz, other.fastPitchDepthHz),
            pitchDecayPerSecond: value(
                pitchDecayPerSecond, other.pitchDecayPerSecond
            ),
            fastPitchDecayPerSecond: value(
                fastPitchDecayPerSecond, other.fastPitchDecayPerSecond
            ),
            bodyDecayPerSecond: value(
                bodyDecayPerSecond, other.bodyDecayPerSecond
            ),
            subDecayPerSecond: value(subDecayPerSecond, other.subDecayPerSecond),
            secondHarmonicLevel: value(
                secondHarmonicLevel, other.secondHarmonicLevel
            ),
            bodyDrive: value(bodyDrive, other.bodyDrive),
            subLevel: value(subLevel, other.subLevel),
            noiseClickLevel: value(noiseClickLevel, other.noiseClickLevel),
            tonalClickLevel: value(tonalClickLevel, other.tonalClickLevel),
            clickFrequencyHz: value(clickFrequencyHz, other.clickFrequencyHz),
            presenceScale: value(presenceScale, other.presenceScale)
        )
    }

    /// A bounded score-side retry movement for calibrated kick-source and
    /// kick/foundation relationship misses. Positive pressure shortens and
    /// firms the existing body while raising its click components slightly;
    /// negative pressure lengthens and softens that same source. Zero is
    /// exactly identity-preserving.
    package func qualityRetryAdjusted(
        pressure requestedPressure: Double
    ) -> Self {
        let pressure = min(1, max(-1, requestedPressure))
        guard pressure != 0 else { return self }
        func bounded(
            _ value: Double,
            scale: Double,
            range: ClosedRange<Double>
        ) -> Double {
            min(range.upperBound, max(range.lowerBound,
                value * (1 + scale * pressure)
            ))
        }
        return Self(
            fundamentalHz: fundamentalHz,
            pitchDepthHz: pitchDepthHz,
            fastPitchDepthHz: fastPitchDepthHz,
            pitchDecayPerSecond: pitchDecayPerSecond,
            fastPitchDecayPerSecond: fastPitchDecayPerSecond,
            bodyDecayPerSecond: bounded(
                bodyDecayPerSecond,
                scale: 0.08,
                range: 13...24
            ),
            subDecayPerSecond: subDecayPerSecond,
            secondHarmonicLevel: secondHarmonicLevel,
            bodyDrive: bounded(
                bodyDrive,
                scale: 0.26,
                range: 0.85...1.42
            ),
            subLevel: bounded(
                subLevel,
                scale: 0.12,
                range: 0.15...0.30
            ),
            noiseClickLevel: bounded(
                noiseClickLevel,
                scale: 0.08,
                range: 0.045...0.11
            ),
            tonalClickLevel: bounded(
                tonalClickLevel,
                scale: 0.08,
                range: 0.03...0.075
            ),
            clickFrequencyHz: clickFrequencyHz,
            presenceScale: presenceScale
        )
    }

    /// The final serial proposal resolves the coupled source-dynamics miss
    /// where ordinary positive pressure raises attack/body contrast by driving
    /// the body harder, but consequently exceeds the calibrated crest-
    /// reduction ceiling. This bounded articulation instead shortens and
    /// softens the body while lifting only the existing click components. It
    /// remains the same kick identity and uses no new renderer-side decision.
    package func qualityRetryTransientRecoveryAdjusted() -> Self {
        func bounded(
            _ value: Double,
            scale: Double,
            range: ClosedRange<Double>
        ) -> Double {
            min(range.upperBound, max(range.lowerBound, value * scale))
        }
        return Self(
            fundamentalHz: fundamentalHz,
            pitchDepthHz: pitchDepthHz,
            fastPitchDepthHz: fastPitchDepthHz,
            pitchDecayPerSecond: pitchDecayPerSecond,
            fastPitchDecayPerSecond: fastPitchDecayPerSecond,
            bodyDecayPerSecond: bounded(
                bodyDecayPerSecond,
                scale: 1.10,
                range: 13...24
            ),
            subDecayPerSecond: subDecayPerSecond,
            secondHarmonicLevel: secondHarmonicLevel,
            bodyDrive: bounded(
                bodyDrive,
                scale: 0.88,
                range: 0.85...1.42
            ),
            subLevel: bounded(
                subLevel,
                scale: 0.92,
                range: 0.15...0.30
            ),
            noiseClickLevel: bounded(
                noiseClickLevel,
                scale: 1.30,
                range: 0.045...0.11
            ),
            tonalClickLevel: bounded(
                tonalClickLevel,
                scale: 1.30,
                range: 0.03...0.075
            ),
            clickFrequencyHz: clickFrequencyHz,
            presenceScale: presenceScale
        )
    }

    package var isBoundedAndFinite: Bool {
        let values = [
            fundamentalHz, pitchDepthHz, fastPitchDepthHz,
            pitchDecayPerSecond, fastPitchDecayPerSecond,
            bodyDecayPerSecond, subDecayPerSecond, secondHarmonicLevel,
            bodyDrive, subLevel, noiseClickLevel, tonalClickLevel,
            clickFrequencyHz, presenceScale,
        ]
        return values.allSatisfy(\.isFinite) &&
            (38...52).contains(fundamentalHz) &&
            (140...300).contains(pitchDepthHz) &&
            (16...42).contains(fastPitchDepthHz) &&
            (38...72).contains(pitchDecayPerSecond) &&
            (120...190).contains(fastPitchDecayPerSecond) &&
            (13...24).contains(bodyDecayPerSecond) &&
            (10...16).contains(subDecayPerSecond) &&
            (0.04...0.15).contains(secondHarmonicLevel) &&
            (0.85...1.42).contains(bodyDrive) &&
            (0.15...0.30).contains(subLevel) &&
            (0.045...0.11).contains(noiseClickLevel) &&
            (0.03...0.075).contains(tonalClickLevel) &&
            (1_650...3_600).contains(clickFrequencyHz) &&
            (0.45...1).contains(presenceScale)
    }
}

/// One bar of a continuous trajectory. Start and end values are interpolated
/// at exact event/sample positions by DSP; adjacent bars share endpoints.
package struct KickMorphologyArticulation: Equatable, Sendable {
    package let version: String
    package let absoluteBar: Int
    package let presentationBar: Int
    package let segmentIndex: Int
    package let episodeID: UInt64
    package let operatorKind: LongHorizonEpisodeOperator
    package let episodeRelativeBar: Int
    package let fromHome: KickMorphologyHome
    package let toHome: KickMorphologyHome
    package let startProgress: Double
    package let endProgress: Double
    package let start: KickMorphologyParameters
    package let end: KickMorphologyParameters

    package func parameters(atBarProgress progress: Double) -> KickMorphologyParameters {
        start.interpolated(to: end, progress: progress)
    }

    package func qualityRetryAdjusted(pressure: Double) -> Self {
        guard pressure != 0 else { return self }
        return Self(
            version: version,
            absoluteBar: absoluteBar,
            presentationBar: presentationBar,
            segmentIndex: segmentIndex,
            episodeID: episodeID,
            operatorKind: operatorKind,
            episodeRelativeBar: episodeRelativeBar,
            fromHome: fromHome,
            toHome: toHome,
            startProgress: startProgress,
            endProgress: endProgress,
            start: start.qualityRetryAdjusted(pressure: pressure),
            end: end.qualityRetryAdjusted(pressure: pressure)
        )
    }

    package func qualityRetryTransientRecoveryAdjusted() -> Self {
        Self(
            version: version,
            absoluteBar: absoluteBar,
            presentationBar: presentationBar,
            segmentIndex: segmentIndex,
            episodeID: episodeID,
            operatorKind: operatorKind,
            episodeRelativeBar: episodeRelativeBar,
            fromHome: fromHome,
            toHome: toHome,
            startProgress: startProgress,
            endProgress: endProgress,
            start: start.qualityRetryTransientRecoveryAdjusted(),
            end: end.qualityRetryTransientRecoveryAdjusted()
        )
    }

    package var isComplete: Bool {
        version == KickMorphologyResolver.version && absoluteBar >= 0 &&
            presentationBar >= absoluteBar && segmentIndex >= 0 &&
            episodeRelativeBar >= 0 &&
            (0...1).contains(startProgress) &&
            (0...1).contains(endProgress) &&
            start.isBoundedAndFinite &&
            end.isBoundedAndFinite
    }
}

/// Episode-bound owner for audible held kick materials. Ordinary episode
/// handoffs use one 32-bar raised cosine. Recovery deliberately stages a
/// relaxed transition, a 32-bar relaxed plateau, a second 32-bar descent, and
/// then a held ghost-soft state. Missing context fails closed to balanced.
package enum KickMorphologyResolver {
    package static let version = "kick-morphology.episode-material.v3"
    package static let transitionBarCount = 32
    package static let recoveryRelaxedHoldBarCount = 32
    package static let recoveryGhostTransitionStartBar =
        transitionBarCount + recoveryRelaxedHoldBarCount
    package static let recoveryGhostHoldStartBar =
        recoveryGhostTransitionStartBar + transitionBarCount

    package static func articulation(
        sessionSeed: UInt64,
        absoluteBar requestedBar: Int,
        presentationBar requestedPresentationBar: Int? = nil,
        episodeContext: KickMorphologyEpisodeContext? = nil,
        qualityRetryOrdinal requestedRetryOrdinal: Int = 0,
        qualityRecoveryIntent: AutonomousQualityRecoveryIntent = .neutral
    ) -> KickMorphologyArticulation {
        let absoluteBar = max(0, requestedBar)
        let presentationBar = max(
            absoluteBar,
            requestedPresentationBar ?? absoluteBar
        )
        guard let episodeContext,
              presentationBar >= episodeContext.startedAtPresentationBar else {
            return retryAdjusted(
                balancedFallback(
                    sessionSeed: sessionSeed,
                    absoluteBar: absoluteBar,
                    presentationBar: presentationBar
                ),
                ordinal: requestedRetryOrdinal,
                intent: qualityRecoveryIntent
            )
        }
        let relativeBar = presentationBar -
            episodeContext.startedAtPresentationBar
        let startState = materialPosition(
            context: episodeContext,
            relativeBar: relativeBar
        )
        let endState = materialPosition(
            context: episodeContext,
            relativeBar: relativeBar == Int.max ? Int.max : relativeBar + 1
        )
        let anchorHz = 44.0 + Double(sessionSeed % 5) * 0.7
        let from = parameters(for: startState.from, anchorHz: anchorHz)
        let to = parameters(for: startState.to, anchorHz: anchorHz)
        let start = from.interpolated(to: to, progress: startState.progress)
        let end: KickMorphologyParameters
        if startState.from == endState.from, startState.to == endState.to {
            end = from.interpolated(to: to, progress: endState.progress)
        } else {
            let endFrom = parameters(for: endState.from, anchorHz: anchorHz)
            let endTo = parameters(for: endState.to, anchorHz: anchorHz)
            end = endFrom.interpolated(to: endTo, progress: endState.progress)
        }
        return retryAdjusted(KickMorphologyArticulation(
            version: version,
            absoluteBar: absoluteBar,
            presentationBar: presentationBar,
            segmentIndex: episodeContext.episodeIndex,
            episodeID: episodeContext.episodeID,
            operatorKind: episodeContext.operatorKind,
            episodeRelativeBar: relativeBar,
            fromHome: startState.from,
            toHome: startState.to,
            startProgress: startState.progress,
            endProgress: endState.progress,
            start: start,
            end: end
        ), ordinal: requestedRetryOrdinal, intent: qualityRecoveryIntent)
    }

    private static func retryAdjusted(
        _ articulation: KickMorphologyArticulation,
        ordinal requestedOrdinal: Int,
        intent: AutonomousQualityRecoveryIntent
    ) -> KickMorphologyArticulation {
        let ordinal = min(
            AutonomousQualityRetryContinuation.maximumOrdinal,
            max(0, requestedOrdinal)
        )
        if ordinal == AutonomousQualityRetryContinuation.maximumOrdinal {
            switch intent.kickCrestReduction {
            case .increase:
                return articulation.qualityRetryAdjusted(pressure: 1)
            case .decrease, .hold:
                return articulation.qualityRetryTransientRecoveryAdjusted()
            }
        }
        let basePressure = qualityRetryPressure(ordinal: ordinal)
        let pressure: Double = switch intent.kickCrestReduction {
        case .hold: basePressure
        case .increase: abs(basePressure)
        case .decrease: -abs(basePressure)
        }
        return articulation.qualityRetryAdjusted(
            pressure: pressure
        )
    }

    /// Serial variants alternate around the committed trajectory with
    /// increasing bounded pressure. This covers both sides of the calibrated
    /// attack/body interval without retaining or ranking parallel candidates.
    package static func qualityRetryPressure(
        ordinal requestedOrdinal: Int
    ) -> Double {
        let ordinal = min(
            AutonomousQualityRetryContinuation.maximumOrdinal,
            max(0, requestedOrdinal)
        )
        guard ordinal > 0 else { return 0 }
        // The first eight variants define a four-step bipolar vocabulary. The
        // gentle first step can correct a near-boundary miss without crossing
        // an adjacent source-dynamics guardrail; later steps retain moderate,
        // broad, and full-range recovery. A later score-level coherence
        // recovery owns a separate transient-clarity articulation because
        // more body pressure cannot correct a coupled low-attack/high-crest-
        // reduction miss.
        let step = (ordinal + 1) / 2
        let magnitude = step >= 4 ? 1 : Double(step * 2 - 1) / 8
        return ordinal.isMultiple(of: 2) ? -magnitude : magnitude
    }

    package static func balancedFallback(
        sessionSeed: UInt64,
        absoluteBar: Int = 0,
        presentationBar requestedPresentationBar: Int? = nil
    ) -> KickMorphologyArticulation {
        let anchor = parameters(
            for: .balanced,
            anchorHz: 44.0 + Double(sessionSeed % 5) * 0.7
        )
        let boundedAbsoluteBar = max(0, absoluteBar)
        return KickMorphologyArticulation(
            version: version,
            absoluteBar: boundedAbsoluteBar,
            presentationBar: max(
                boundedAbsoluteBar,
                requestedPresentationBar ?? boundedAbsoluteBar
            ),
            segmentIndex: 0,
            episodeID: 0,
            operatorKind: .maintain,
            episodeRelativeBar: 0,
            fromHome: .balanced,
            toHome: .balanced,
            startProgress: 0,
            endProgress: 0,
            start: anchor,
            end: anchor
        )
    }

    private static func materialPosition(
        context: KickMorphologyEpisodeContext,
        relativeBar: Int
    ) -> (from: KickMorphologyHome, to: KickMorphologyHome, progress: Double) {
        let bar = max(0, relativeBar)
        let previous = terminalMaterial(
            for: context.previousOperatorKind ?? .maintain
        )
        if context.operatorKind == .recover {
            if bar < transitionBarCount {
                return (previous, .relaxed, raisedCosine(
                    Double(bar) / Double(transitionBarCount)
                ))
            }
            if bar < recoveryGhostTransitionStartBar {
                return (.relaxed, .relaxed, 1)
            }
            if bar < recoveryGhostHoldStartBar {
                return (.relaxed, .ghostSoft, raisedCosine(
                    Double(bar - recoveryGhostTransitionStartBar) /
                        Double(transitionBarCount)
                ))
            }
            return (.ghostSoft, .ghostSoft, 1)
        }
        let target = terminalMaterial(for: context.operatorKind)
        guard previous != target, bar < transitionBarCount else {
            return (target, target, 1)
        }
        return (previous, target, raisedCosine(
            Double(bar) / Double(transitionBarCount)
        ))
    }

    private static func terminalMaterial(
        for operatorKind: LongHorizonEpisodeOperator
    ) -> KickMorphologyHome {
        switch operatorKind {
        case .maintain, .rise, .recall:
            return .balanced
        case .reframe:
            return .relaxed
        case .recover:
            return .ghostSoft
        case .payoff:
            return .resonantAccent
        }
    }

    private static func raisedCosine(_ progress: Double) -> Double {
        let bounded = min(1, max(0, progress))
        return 0.5 - 0.5 * cos(.pi * bounded)
    }

    private static func parameters(
        for home: KickMorphologyHome,
        anchorHz: Double
    ) -> KickMorphologyParameters {
        switch home {
        case .balanced:
            return KickMorphologyParameters(
                fundamentalHz: anchorHz,
                pitchDepthHz: 205,
                fastPitchDepthHz: 28,
                pitchDecayPerSecond: 48,
                fastPitchDecayPerSecond: 150,
                bodyDecayPerSecond: 17.5,
                subDecayPerSecond: 12.5,
                secondHarmonicLevel: 0.075,
                bodyDrive: 1.22,
                subLevel: 0.22,
                noiseClickLevel: 0.08,
                tonalClickLevel: 0.055,
                clickFrequencyHz: 2_800,
                presenceScale: 1
            )
        case .relaxed:
            return KickMorphologyParameters(
                fundamentalHz: anchorHz - 0.4,
                pitchDepthHz: 175,
                fastPitchDepthHz: 22,
                pitchDecayPerSecond: 44,
                fastPitchDecayPerSecond: 135,
                bodyDecayPerSecond: 16.5,
                subDecayPerSecond: 12,
                secondHarmonicLevel: 0.065,
                bodyDrive: 1.05,
                subLevel: 0.20,
                noiseClickLevel: 0.058,
                tonalClickLevel: 0.04,
                clickFrequencyHz: 2_300,
                presenceScale: 0.78
            )
        case .ghostSoft:
            return KickMorphologyParameters(
                fundamentalHz: anchorHz - 1,
                pitchDepthHz: 140,
                fastPitchDepthHz: 16,
                pitchDecayPerSecond: 40,
                fastPitchDecayPerSecond: 120,
                bodyDecayPerSecond: 14,
                subDecayPerSecond: 11,
                secondHarmonicLevel: 0.05,
                bodyDrive: 0.88,
                subLevel: 0.16,
                noiseClickLevel: 0.045,
                tonalClickLevel: 0.03,
                clickFrequencyHz: 1_800,
                presenceScale: 0.48
            )
        case .resonantAccent:
            return KickMorphologyParameters(
                fundamentalHz: anchorHz - 0.5,
                pitchDepthHz: 180,
                fastPitchDepthHz: 23,
                pitchDecayPerSecond: 43,
                fastPitchDecayPerSecond: 136,
                bodyDecayPerSecond: 18.5,
                subDecayPerSecond: 13,
                secondHarmonicLevel: 0.15,
                bodyDrive: 1.22,
                subLevel: 0.22,
                noiseClickLevel: 0.08,
                tonalClickLevel: 0.055,
                clickFrequencyHz: 1_750,
                presenceScale: 0.90
            )
        }
    }
}
