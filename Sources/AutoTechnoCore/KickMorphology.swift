import Foundation

/// Recognizable source homes inside the one canonical kick voice. They are not
/// genre presets or selectable instruments: the session identity moves between
/// them through one deterministic, long-horizon trajectory.
package enum KickMorphologyHome: String, CaseIterable, Sendable {
    case anchor
    case round
    case taut
    case hammer
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
            clickFrequencyHz: value(clickFrequencyHz, other.clickFrequencyHz)
        )
    }

    /// A bounded score-side retry movement for calibrated kick-source
    /// attack/body misses. Positive pressure shortens the body and raises the
    /// existing click components slightly; negative pressure explores the
    /// inverse direction. Zero is exactly identity-preserving.
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
                scale: 0.20,
                range: 13...24
            ),
            subDecayPerSecond: subDecayPerSecond,
            secondHarmonicLevel: secondHarmonicLevel,
            bodyDrive: bodyDrive,
            subLevel: subLevel,
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
            clickFrequencyHz: clickFrequencyHz
        )
    }

    package var isBoundedAndFinite: Bool {
        let values = [
            fundamentalHz, pitchDepthHz, fastPitchDepthHz,
            pitchDecayPerSecond, fastPitchDecayPerSecond,
            bodyDecayPerSecond, subDecayPerSecond, secondHarmonicLevel,
            bodyDrive, subLevel, noiseClickLevel, tonalClickLevel,
            clickFrequencyHz,
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
            (1.05...1.42).contains(bodyDrive) &&
            (0.15...0.30).contains(subLevel) &&
            (0.045...0.11).contains(noiseClickLevel) &&
            (0.03...0.075).contains(tonalClickLevel) &&
            (1_650...3_600).contains(clickFrequencyHz)
    }
}

/// One bar of a continuous trajectory. Start and end values are interpolated
/// at exact event/sample positions by DSP; adjacent bars share endpoints.
package struct KickMorphologyArticulation: Equatable, Sendable {
    package let version: String
    package let absoluteBar: Int
    package let segmentIndex: Int
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
            segmentIndex: segmentIndex,
            fromHome: fromHome,
            toHome: toHome,
            startProgress: startProgress,
            endProgress: endProgress,
            start: start.qualityRetryAdjusted(pressure: pressure),
            end: end.qualityRetryAdjusted(pressure: pressure)
        )
    }

    package var isComplete: Bool {
        version == KickMorphologyResolver.version && absoluteBar >= 0 &&
            segmentIndex >= 0 && fromHome != toHome &&
            (0...1).contains(startProgress) &&
            (0...1).contains(endProgress) &&
            endProgress >= startProgress && start.isBoundedAndFinite &&
            end.isBoundedAndFinite
    }
}

/// Session-scale owner for a slowly blended kick identity. A 128-bar segment
/// lasts almost four minutes at 130 BPM. Invalid or implausibly distant bars
/// fall back to the legacy anchor instead of authoring unbounded work.
package enum KickMorphologyResolver {
    package static let version = "kick-morphology.score-trajectory.v1"
    package static let segmentBarCount = 128
    package static let maximumSegmentIndex = 4_096

    package static func articulation(
        sessionSeed: UInt64,
        absoluteBar requestedBar: Int,
        qualityRetryOrdinal requestedRetryOrdinal: Int = 0
    ) -> KickMorphologyArticulation {
        let absoluteBar = max(0, requestedBar)
        let segmentIndex = absoluteBar / segmentBarCount
        guard segmentIndex <= maximumSegmentIndex else {
            return legacyAnchor(sessionSeed: sessionSeed, absoluteBar: absoluteBar)
                .qualityRetryAdjusted(
                    pressure: qualityRetryPressure(
                        ordinal: requestedRetryOrdinal
                    )
                )
        }
        let startPosition = Double(absoluteBar) / Double(segmentBarCount)
        let endPosition = Double(absoluteBar + 1) / Double(segmentBarCount)
        let fromHome = home(sessionSeed: sessionSeed, boundaryIndex: segmentIndex)
        let toHome = home(sessionSeed: sessionSeed, boundaryIndex: segmentIndex + 1)
        let localStart = startPosition - Double(segmentIndex)
        let localEnd = min(1, endPosition - Double(segmentIndex))
        let startProgress = raisedCosine(localStart)
        let endProgress = raisedCosine(localEnd)
        let anchorHz = 44.0 + Double(sessionSeed % 5) * 0.7
        let from = parameters(for: fromHome, anchorHz: anchorHz)
        let to = parameters(for: toHome, anchorHz: anchorHz)
        return KickMorphologyArticulation(
            version: version,
            absoluteBar: absoluteBar,
            segmentIndex: segmentIndex,
            fromHome: fromHome,
            toHome: toHome,
            startProgress: startProgress,
            endProgress: endProgress,
            start: from.interpolated(to: to, progress: startProgress),
            end: from.interpolated(to: to, progress: endProgress)
        ).qualityRetryAdjusted(
            pressure: qualityRetryPressure(ordinal: requestedRetryOrdinal)
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
        // The first eight variants define the original four-step bipolar
        // morphology vocabulary. A later score-level coherence recovery reuses
        // full positive pressure instead of expanding these calibrated bounds.
        let magnitude = min(1, Double((ordinal + 1) / 2) / 4)
        return ordinal.isMultiple(of: 2) ? -magnitude : magnitude
    }

    package static func legacyAnchor(
        sessionSeed: UInt64,
        absoluteBar: Int = 0
    ) -> KickMorphologyArticulation {
        let anchor = parameters(
            for: .anchor,
            anchorHz: 44.0 + Double(sessionSeed % 5) * 0.7
        )
        return KickMorphologyArticulation(
            version: version,
            absoluteBar: max(0, absoluteBar),
            segmentIndex: max(0, absoluteBar) / segmentBarCount,
            fromHome: .anchor,
            toHome: .round,
            startProgress: 0,
            endProgress: 0,
            start: anchor,
            end: anchor
        )
    }

    private static func home(
        sessionSeed: UInt64,
        boundaryIndex: Int
    ) -> KickMorphologyHome {
        guard boundaryIndex > 0 else { return .anchor }
        let homes = KickMorphologyHome.allCases
        var selected = 0
        for boundary in 1...boundaryIndex {
            let entropy = SceneDNA.derivedSeed(
                scene: sessionSeed,
                domain: 0x4B49_434B_4D4F_5250,
                index: boundary
            )
            let offset = 1 + Int(entropy % UInt64(homes.count - 1))
            selected = (selected + offset) % homes.count
        }
        return homes[selected]
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
        case .anchor:
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
                clickFrequencyHz: 2_800
            )
        case .round:
            return KickMorphologyParameters(
                fundamentalHz: anchorHz - 1.4,
                pitchDepthHz: 165,
                fastPitchDepthHz: 22,
                pitchDecayPerSecond: 42,
                fastPitchDecayPerSecond: 132,
                bodyDecayPerSecond: 14.8,
                subDecayPerSecond: 10.8,
                secondHarmonicLevel: 0.05,
                bodyDrive: 1.10,
                subLevel: 0.285,
                noiseClickLevel: 0.055,
                tonalClickLevel: 0.04,
                clickFrequencyHz: 2_050
            )
        case .taut:
            return KickMorphologyParameters(
                fundamentalHz: anchorHz + 2.1,
                pitchDepthHz: 238,
                fastPitchDepthHz: 34,
                pitchDecayPerSecond: 59,
                fastPitchDecayPerSecond: 172,
                bodyDecayPerSecond: 22.4,
                subDecayPerSecond: 15.2,
                secondHarmonicLevel: 0.10,
                bodyDrive: 1.30,
                subLevel: 0.17,
                noiseClickLevel: 0.095,
                tonalClickLevel: 0.067,
                clickFrequencyHz: 3_350
            )
        case .hammer:
            return KickMorphologyParameters(
                fundamentalHz: anchorHz - 0.3,
                pitchDepthHz: 286,
                fastPitchDepthHz: 39,
                pitchDecayPerSecond: 70,
                fastPitchDecayPerSecond: 185,
                bodyDecayPerSecond: 19.2,
                subDecayPerSecond: 13.4,
                secondHarmonicLevel: 0.14,
                bodyDrive: 1.40,
                subLevel: 0.19,
                noiseClickLevel: 0.105,
                tonalClickLevel: 0.07,
                clickFrequencyHz: 1_750
            )
        }
    }
}
