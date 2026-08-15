import AutoTechnoCore
import Foundation

package struct UpperTimbreSlideWindow: Codable, Equatable, Sendable {
    package let startFrame: Int
    package let endFrame: Int

    package init(startFrame: Int, endFrame: Int) {
        let start = max(0, min(startFrame, endFrame))
        self.startFrame = start
        self.endFrame = max(start, max(startFrame, endFrame))
    }
}

package struct UpperTimbreStereoFrame: Codable, Equatable, Sendable {
    package let left: Float
    package let right: Float

    package init(left: Float, right: Float) {
        self.left = left
        self.right = right
    }
}

/// Applied renderer metadata for one anchor retrigger. The analyzer combines
/// it with the exact dry anchor tap; no counterfactual render or raw PCM is
/// retained in the quality report.
package struct UpperVelocityExpressionWindow: Equatable, Sendable {
    package let onsetFrame: Int
    package let endFrame: Int
    package let velocity: Double
    package let appliedStartFrequency: Double
    package let spectralEnvelopeScale: Double
    package let decayScale: Double

    package init(
        onsetFrame: Int,
        endFrame: Int,
        velocity: Double,
        appliedStartFrequency: Double,
        spectralEnvelopeScale: Double,
        decayScale: Double
    ) {
        self.onsetFrame = onsetFrame
        self.endFrame = endFrame
        self.velocity = velocity
        self.appliedStartFrequency = appliedStartFrequency
        self.spectralEnvelopeScale = spectralEnvelopeScale
        self.decayScale = decayScale
    }
}

/// Bounded onset-local evidence that a score velocity reached both the DSP
/// projection and the exact dry anchor signal. Ratios are descriptive until a
/// calibrated policy supplies journey- and route-aware ranges.
package struct UpperVelocityExpressionEvidence: Codable, Equatable, Sendable {
    package let onsetFrame: Int
    package let analyzedEndFrame: Int
    package let analyzedFrameCount: Int
    package let velocity: Double
    package let appliedStartFrequency: Double
    package let spectralEnvelopeScale: Double
    package let decayScale: Double
    package let sourceRMS: Double
    package let attackHighBandRatio: Double
    package let tailToAttackDB: Double
    package let complete: Bool
}

/// Signal-domain inputs remain local to detached preparation. Only the reduced
/// `UpperTimbreEvidence` result is serializable or eligible to cross into Core.
package struct UpperTimbreAnalysisInput: Equatable, Sendable {
    package let left: [Float]
    package let right: [Float]
    package let sampleRate: Double
    package let accentedOnsetFrames: [Int]
    package let unaccentedOnsetFrames: [Int]
    package let slideWindows: [UpperTimbreSlideWindow]
    package let detectedAttackFrames: [Int]
    package let velocityExpressionWindows: [UpperVelocityExpressionWindow]
    package let protectedReferenceMono: [Float]
    package let precedingFrame: UpperTimbreStereoFrame?
    package let followingFrame: UpperTimbreStereoFrame?

    package init(
        left: [Float],
        right: [Float],
        sampleRate: Double,
        accentedOnsetFrames: [Int] = [],
        unaccentedOnsetFrames: [Int] = [],
        slideWindows: [UpperTimbreSlideWindow] = [],
        detectedAttackFrames: [Int] = [],
        velocityExpressionWindows: [UpperVelocityExpressionWindow] = [],
        protectedReferenceMono: [Float] = [],
        precedingFrame: UpperTimbreStereoFrame? = nil,
        followingFrame: UpperTimbreStereoFrame? = nil
    ) {
        self.left = left
        self.right = right
        self.sampleRate = sampleRate
        self.accentedOnsetFrames = accentedOnsetFrames
        self.unaccentedOnsetFrames = unaccentedOnsetFrames
        self.slideWindows = slideWindows
        self.detectedAttackFrames = detectedAttackFrames
        self.velocityExpressionWindows = velocityExpressionWindows
        self.protectedReferenceMono = protectedReferenceMono
        self.precedingFrame = precedingFrame
        self.followingFrame = followingFrame
    }
}

/// Interpretable, bounded timbral evidence. Every scalar is descriptive until a
/// later calibrated policy defines checkpoint- and role-aware ranges.
package struct UpperTimbreEvidence: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let sampleRate: Double
    package let analyzedFrameCount: Int
    package let finite: Bool
    package let rms: Double
    package let crestFactor: Double
    package let filterContourRise: Double
    package let filterContourDecay: Double
    package let accentContrastDB: Double
    package let accentedOnsetCount: Int
    package let unaccentedOnsetCount: Int
    package let slideMaximumDelta: Double
    package let slideWindowCount: Int
    package let duplicateAttackCount: Int
    package let velocityExpression: [UpperVelocityExpressionEvidence]
    package let detuneMotionDepth: Double
    package let detuneMotionPeriodSeconds: Double
    package let highBandEnergyRatio: Double
    package let aliasBandEnergyRatio: Double
    package let stereoWidthRatio: Double
    package let monoLossDB: Double
    package let stereoCorrelation: Double
    package let maskingOverlap: Double
    package let maximumBoundaryDelta: Double

    package static func aggregating(_ windows: [UpperTimbreEvidence]) -> UpperTimbreEvidence {
        UpperTimbreEvidenceAnalyzer.aggregate(windows)
    }

    /// Combines role-local articulation measurements with one mix-domain
    /// observation. Resonant contour/accent/slide facts come only from the
    /// anchor tap; oscillator motion comes only from shadow/response; width,
    /// masking, spectrum, level, and boundaries come from the named mix tap.
    package static func attributing(
        resonantAnchor: UpperTimbreEvidence,
        detunedCompanions: UpperTimbreEvidence,
        mix: UpperTimbreEvidence
    ) -> UpperTimbreEvidence {
        let compatible = resonantAnchor.schemaVersion == mix.schemaVersion &&
            detunedCompanions.schemaVersion == mix.schemaVersion &&
            resonantAnchor.sampleRate == mix.sampleRate &&
            detunedCompanions.sampleRate == mix.sampleRate &&
            resonantAnchor.analyzedFrameCount == mix.analyzedFrameCount &&
            detunedCompanions.analyzedFrameCount == mix.analyzedFrameCount
        return UpperTimbreEvidence(
            schemaVersion: mix.schemaVersion,
            sampleRate: mix.sampleRate,
            analyzedFrameCount: mix.analyzedFrameCount,
            finite: compatible && resonantAnchor.finite && detunedCompanions.finite && mix.finite,
            rms: mix.rms,
            crestFactor: mix.crestFactor,
            filterContourRise: resonantAnchor.filterContourRise,
            filterContourDecay: resonantAnchor.filterContourDecay,
            accentContrastDB: resonantAnchor.accentContrastDB,
            accentedOnsetCount: resonantAnchor.accentedOnsetCount,
            unaccentedOnsetCount: resonantAnchor.unaccentedOnsetCount,
            slideMaximumDelta: resonantAnchor.slideMaximumDelta,
            slideWindowCount: resonantAnchor.slideWindowCount,
            duplicateAttackCount: resonantAnchor.duplicateAttackCount,
            velocityExpression: resonantAnchor.velocityExpression,
            detuneMotionDepth: detunedCompanions.detuneMotionDepth,
            detuneMotionPeriodSeconds: detunedCompanions.detuneMotionPeriodSeconds,
            highBandEnergyRatio: mix.highBandEnergyRatio,
            aliasBandEnergyRatio: mix.aliasBandEnergyRatio,
            stereoWidthRatio: mix.stereoWidthRatio,
            monoLossDB: mix.monoLossDB,
            stereoCorrelation: mix.stereoCorrelation,
            maskingOverlap: mix.maskingOverlap,
            maximumBoundaryDelta: mix.maximumBoundaryDelta
        )
    }

    package var fingerprint: String {
        var hash: UInt64 = 0xcbf29ce484222325
        func mix(_ value: UInt64) {
            var remaining = value
            for _ in 0..<8 {
                hash ^= remaining & 0xff
                hash &*= 0x100000001b3
                remaining >>= 8
            }
        }
        func signed(_ value: Int) -> UInt64 {
            UInt64(bitPattern: Int64(value))
        }
        mix(signed(schemaVersion))
        mix(sampleRate.bitPattern)
        mix(signed(analyzedFrameCount))
        mix(finite ? 1 : 0)
        mix(rms.bitPattern)
        mix(crestFactor.bitPattern)
        mix(filterContourRise.bitPattern)
        mix(filterContourDecay.bitPattern)
        mix(accentContrastDB.bitPattern)
        mix(signed(accentedOnsetCount))
        mix(signed(unaccentedOnsetCount))
        mix(slideMaximumDelta.bitPattern)
        mix(signed(slideWindowCount))
        mix(signed(duplicateAttackCount))
        mix(UInt64(velocityExpression.count))
        for event in velocityExpression {
            mix(signed(event.onsetFrame))
            mix(signed(event.analyzedEndFrame))
            mix(signed(event.analyzedFrameCount))
            mix(event.velocity.bitPattern)
            mix(event.appliedStartFrequency.bitPattern)
            mix(event.spectralEnvelopeScale.bitPattern)
            mix(event.decayScale.bitPattern)
            mix(event.sourceRMS.bitPattern)
            mix(event.attackHighBandRatio.bitPattern)
            mix(event.tailToAttackDB.bitPattern)
            mix(event.complete ? 1 : 0)
        }
        mix(detuneMotionDepth.bitPattern)
        mix(detuneMotionPeriodSeconds.bitPattern)
        mix(highBandEnergyRatio.bitPattern)
        mix(aliasBandEnergyRatio.bitPattern)
        mix(stereoWidthRatio.bitPattern)
        mix(monoLossDB.bitPattern)
        mix(stereoCorrelation.bitPattern)
        mix(maskingOverlap.bitPattern)
        mix(maximumBoundaryDelta.bitPattern)
        return fixedWidthFingerprintHex(hash)
    }
}

package enum UpperTimbreEvidenceAnalyzer {
    /// Version 3 adds bounded, onset-local anchor velocity expression while
    /// retaining version 2's exact protected-rhythm masking reference.
    package static let schemaVersion = 3
    /// Covers one canonical 130 BPM bar through 192 kHz without truncation.
    /// Inputs beyond this detached-preparation bound are marked incomplete.
    package static let maximumFrames = 524_288
    package static let maximumOnsets = 128
    package static let maximumMetadataItems = 512
    package static let maximumSlideWindows = 64
    package static let maximumEvidenceWindows = 64
    package static let maximumVelocityExpressionWindows = 128
    package static let maximumVelocityExpressionEvents = 512
    private static let spectralFrameLimit = 1_024
    private static let epsilon = 0.000_000_000_001

    package static func analyze(_ input: UpperTimbreAnalysisInput) -> UpperTimbreEvidence {
        let rateIsValid = input.sampleRate.isFinite && input.sampleRate > 0
        let sampleRate = rateIsValid ? input.sampleRate : 0
        let effectiveRate = max(1, sampleRate)
        let stereoCount = min(input.left.count, input.right.count)
        let frameCount = min(maximumFrames, stereoCount)
        let boundedVelocityWindows = Array(
            input.velocityExpressionWindows.prefix(maximumVelocityExpressionWindows)
        )
        let metadataComplete = input.accentedOnsetFrames.count <= maximumMetadataItems &&
            input.unaccentedOnsetFrames.count <= maximumMetadataItems &&
            input.detectedAttackFrames.count <= maximumMetadataItems &&
            input.slideWindows.count <= maximumSlideWindows &&
            input.velocityExpressionWindows.count <= maximumVelocityExpressionWindows
        let velocityMetadataValuesValid = boundedVelocityWindows.allSatisfy {
            $0.velocity.isFinite && $0.appliedStartFrequency.isFinite &&
                $0.spectralEnvelopeScale.isFinite && $0.decayScale.isFinite &&
                $0.velocity >= 0 && $0.velocity <= 1 &&
                $0.appliedStartFrequency > 0 &&
                $0.spectralEnvelopeScale >= 0.40 &&
                $0.spectralEnvelopeScale <= 1.60 &&
                $0.decayScale >= 0.80 && $0.decayScale <= 1.20
        }
        let velocityMetadataFramesValid = boundedVelocityWindows.allSatisfy {
            $0.onsetFrame >= 0 && $0.onsetFrame < stereoCount &&
                $0.endFrame >= $0.onsetFrame && $0.endFrame <= stereoCount
        }
        let protectedComplete = input.protectedReferenceMono.isEmpty ||
            (input.protectedReferenceMono.count == stereoCount &&
                input.protectedReferenceMono.count <= maximumFrames)
        var finite = rateIsValid && input.left.count == input.right.count &&
            stereoCount <= maximumFrames && metadataComplete && protectedComplete &&
            velocityMetadataValuesValid && velocityMetadataFramesValid
        var left = [Double]()
        var right = [Double]()
        left.reserveCapacity(frameCount)
        right.reserveCapacity(frameCount)
        for index in 0..<frameCount {
            let leftSample = Double(input.left[index])
            let rightSample = Double(input.right[index])
            finite = finite && leftSample.isFinite && rightSample.isFinite
            left.append(leftSample.isFinite ? leftSample : 0)
            right.append(rightSample.isFinite ? rightSample : 0)
        }

        var protected = [Double]()
        protected.reserveCapacity(min(maximumFrames, input.protectedReferenceMono.count))
        for sample in input.protectedReferenceMono.prefix(maximumFrames) {
            let value = Double(sample)
            finite = finite && value.isFinite
            protected.append(value.isFinite ? value : 0)
        }

        var preceding = input.precedingFrame
        var following = input.followingFrame
        if let frame = preceding,
           !frame.left.isFinite || !frame.right.isFinite {
            finite = false
            preceding = nil
        }
        if let frame = following,
           !frame.left.isFinite || !frame.right.isFinite {
            finite = false
            following = nil
        }

        let mono = zip(left, right).map { ($0 + $1) * 0.5 }
        let side = zip(left, right).map { ($0 - $1) * 0.5 }
        let leftEnergy = left.reduce(0) { $0 + $1 * $1 }
        let rightEnergy = right.reduce(0) { $0 + $1 * $1 }
        let stereoEnergy = (leftEnergy + rightEnergy) * 0.5
        let monoEnergy = mono.reduce(0) { $0 + $1 * $1 }
        let sideEnergy = side.reduce(0) { $0 + $1 * $1 }
        let divisor = Double(max(1, frameCount))
        let rms = sqrt(stereoEnergy / divisor)
        let monoRMS = sqrt(monoEnergy / divisor)
        let sideRMS = sqrt(sideEnergy / divisor)
        let peak = zip(left, right).reduce(0.0) { result, pair in
            max(result, abs(pair.0), abs(pair.1))
        }
        let crest = rms > epsilon ? peak / rms : 0
        let width = rms > epsilon ? min(120, sideRMS / max(monoRMS, epsilon)) : 0
        let monoLoss = rms > epsilon
            ? min(0, max(-120, 20 * log10(max(monoRMS, epsilon) / rms))) : 0
        let cross = zip(left, right).reduce(0.0) { $0 + $1.0 * $1.1 }
        let correlation: Double
        if leftEnergy <= epsilon && rightEnergy <= epsilon {
            correlation = 1
        } else if leftEnergy <= epsilon || rightEnergy <= epsilon {
            correlation = 0
        } else {
            correlation = min(1, max(-1, cross / sqrt(leftEnergy * rightEnergy)))
        }

        let accented = boundedFrames(input.accentedOnsetFrames, count: frameCount)
        let unaccented = boundedFrames(input.unaccentedOnsetFrames, count: frameCount)
        let contour = filterContour(
            mono: mono,
            onsetFrames: Array(Set(accented + unaccented)).sorted(),
            sampleRate: effectiveRate
        )
        let accentContrast = contrastDB(
            accented: onsetLevels(mono: mono, frames: accented, sampleRate: effectiveRate),
            unaccented: onsetLevels(mono: mono, frames: unaccented, sampleRate: effectiveRate)
        )
        let slides = input.slideWindows.prefix(maximumSlideWindows).compactMap { window -> UpperTimbreSlideWindow? in
            let start = min(frameCount, max(0, window.startFrame))
            let end = min(frameCount, max(start, window.endFrame))
            return end > start ? UpperTimbreSlideWindow(startFrame: start, endFrame: end) : nil
        }
        let attacks = boundedFrames(input.detectedAttackFrames, count: frameCount)
        var slideMaximumDelta = 0.0
        var duplicateAttackCount = 0
        for slide in slides {
            if slide.endFrame - slide.startFrame > 1 {
                for index in (slide.startFrame + 1)..<slide.endFrame {
                    slideMaximumDelta = max(slideMaximumDelta, abs(mono[index] - mono[index - 1]))
                }
            }
            duplicateAttackCount += attacks.filter {
                $0 > slide.startFrame && $0 < slide.endFrame
            }.count
        }

        let detune = detuneMotion(mono: mono, sampleRate: effectiveRate)
        let velocityExpression = velocityExpressionEvidence(
            mono: mono,
            windows: boundedVelocityWindows,
            sampleRate: sampleRate
        )
        let spectrum = spectralSummary(mono, sampleRate: effectiveRate)
        let protectedSpectrum = spectralSummary(protected, sampleRate: effectiveRate)
        let masking = maskingOverlap(spectrum.bands, protectedSpectrum.bands)
        let boundaryDelta = maximumBoundaryDelta(
            left: left,
            right: right,
            preceding: preceding,
            following: following
        )

        return UpperTimbreEvidence(
            schemaVersion: schemaVersion,
            sampleRate: sampleRate,
            analyzedFrameCount: frameCount,
            finite: finite,
            rms: finiteValue(rms),
            crestFactor: finiteValue(crest),
            filterContourRise: finiteValue(contour.rise),
            filterContourDecay: finiteValue(contour.decay),
            accentContrastDB: finiteValue(accentContrast),
            accentedOnsetCount: accented.count,
            unaccentedOnsetCount: unaccented.count,
            slideMaximumDelta: finiteValue(slideMaximumDelta),
            slideWindowCount: slides.count,
            duplicateAttackCount: duplicateAttackCount,
            velocityExpression: velocityExpression,
            detuneMotionDepth: finiteValue(detune.depth),
            detuneMotionPeriodSeconds: finiteValue(detune.period),
            highBandEnergyRatio: finiteValue(spectrum.highRatio),
            aliasBandEnergyRatio: finiteValue(spectrum.aliasRatio),
            stereoWidthRatio: finiteValue(width),
            monoLossDB: finiteValue(monoLoss),
            stereoCorrelation: finiteValue(correlation),
            maskingOverlap: finiteValue(masking),
            maximumBoundaryDelta: finiteValue(boundaryDelta)
        )
    }

    /// Combines already reduced windows without retaining or reconstructing
    /// PCM. Continuous evidence is frame-count weighted, event counts are
    /// saturating sums, and discontinuity evidence preserves the worst case.
    /// More than the fixed window bound is deterministically truncated and
    /// marked non-finite so it cannot be mistaken for qualified evidence.
    package static func aggregate(_ evidence: [UpperTimbreEvidence]) -> UpperTimbreEvidence {
        let windows = Array(evidence.prefix(maximumEvidenceWindows))
        guard let first = windows.first else {
            return UpperTimbreEvidence(
                schemaVersion: schemaVersion,
                sampleRate: 0,
                analyzedFrameCount: 0,
                finite: false,
                rms: 0,
                crestFactor: 0,
                filterContourRise: 0,
                filterContourDecay: 0,
                accentContrastDB: 0,
                accentedOnsetCount: 0,
                unaccentedOnsetCount: 0,
                slideMaximumDelta: 0,
                slideWindowCount: 0,
                duplicateAttackCount: 0,
                velocityExpression: [],
                detuneMotionDepth: 0,
                detuneMotionPeriodSeconds: 0,
                highBandEnergyRatio: 0,
                aliasBandEnergyRatio: 0,
                stereoWidthRatio: 0,
                monoLossDB: 0,
                stereoCorrelation: 0,
                maskingOverlap: 0,
                maximumBoundaryDelta: 0
            )
        }
        let totalFrames = windows.reduce(0) { saturatingAdd($0, max(0, $1.analyzedFrameCount)) }
        func weighted(_ value: (UpperTimbreEvidence) -> Double) -> Double {
            guard totalFrames > 0 else { return 0 }
            let sum = windows.reduce(0.0) { result, window in
                result + value(window) * Double(max(0, window.analyzedFrameCount))
            }
            return finiteValue(sum / Double(totalFrames))
        }
        let consistentRate = windows.allSatisfy { $0.sampleRate == first.sampleRate }
        let totalVelocityExpressionCount = windows.reduce(0) {
            saturatingAdd($0, $1.velocityExpression.count)
        }
        var velocityExpression: [UpperVelocityExpressionEvidence] = []
        velocityExpression.reserveCapacity(min(
            maximumVelocityExpressionEvents,
            totalVelocityExpressionCount
        ))
        var frameOffset = 0
        for window in windows {
            for event in window.velocityExpression {
                if velocityExpression.count == maximumVelocityExpressionEvents { break }
                velocityExpression.append(UpperVelocityExpressionEvidence(
                    onsetFrame: saturatingAdd(frameOffset, event.onsetFrame),
                    analyzedEndFrame: saturatingAdd(
                        frameOffset,
                        event.analyzedEndFrame
                    ),
                    analyzedFrameCount: event.analyzedFrameCount,
                    velocity: event.velocity,
                    appliedStartFrequency: event.appliedStartFrequency,
                    spectralEnvelopeScale: event.spectralEnvelopeScale,
                    decayScale: event.decayScale,
                    sourceRMS: event.sourceRMS,
                    attackHighBandRatio: event.attackHighBandRatio,
                    tailToAttackDB: event.tailToAttackDB,
                    complete: event.complete
                ))
            }
            frameOffset = saturatingAdd(frameOffset, window.analyzedFrameCount)
        }
        let valid = evidence.count <= maximumEvidenceWindows && consistentRate &&
            totalVelocityExpressionCount <= maximumVelocityExpressionEvents &&
            windows.allSatisfy { $0.finite && $0.schemaVersion == schemaVersion }
        return UpperTimbreEvidence(
            schemaVersion: schemaVersion,
            sampleRate: first.sampleRate,
            analyzedFrameCount: totalFrames,
            finite: valid,
            rms: weighted(\.rms),
            crestFactor: weighted(\.crestFactor),
            filterContourRise: weighted(\.filterContourRise),
            filterContourDecay: weighted(\.filterContourDecay),
            accentContrastDB: weighted(\.accentContrastDB),
            accentedOnsetCount: windows.reduce(0) { saturatingAdd($0, $1.accentedOnsetCount) },
            unaccentedOnsetCount: windows.reduce(0) { saturatingAdd($0, $1.unaccentedOnsetCount) },
            slideMaximumDelta: windows.map(\.slideMaximumDelta).max() ?? 0,
            slideWindowCount: windows.reduce(0) { saturatingAdd($0, $1.slideWindowCount) },
            duplicateAttackCount: windows.reduce(0) { saturatingAdd($0, $1.duplicateAttackCount) },
            velocityExpression: velocityExpression,
            detuneMotionDepth: weighted(\.detuneMotionDepth),
            detuneMotionPeriodSeconds: weighted(\.detuneMotionPeriodSeconds),
            highBandEnergyRatio: weighted(\.highBandEnergyRatio),
            aliasBandEnergyRatio: weighted(\.aliasBandEnergyRatio),
            stereoWidthRatio: weighted(\.stereoWidthRatio),
            monoLossDB: weighted(\.monoLossDB),
            stereoCorrelation: weighted(\.stereoCorrelation),
            maskingOverlap: weighted(\.maskingOverlap),
            maximumBoundaryDelta: windows.map(\.maximumBoundaryDelta).max() ?? 0
        )
    }

    private static func boundedFrames(_ frames: [Int], count: Int) -> [Int] {
        Array(Set(frames.prefix(maximumMetadataItems).filter { $0 >= 0 && $0 < count }))
            .sorted()
            .prefix(maximumOnsets)
            .map { $0 }
    }

    private static func onsetLevels(mono: [Double], frames: [Int], sampleRate: Double) -> [Double] {
        let window = max(1, min(2_048, Int((sampleRate * 0.04).rounded())))
        return frames.map { start in
            let end = min(mono.count, start + window)
            guard end > start else { return 0 }
            let energy = mono[start..<end].reduce(0.0) { $0 + $1 * $1 }
            return sqrt(energy / Double(end - start))
        }
    }

    /// Reduces each exact anchor retrigger to one fixed-size diagnostic. The
    /// high-band ratio and tail/attack ratio are gain-normalized by construction,
    /// so the direct velocity gain cannot masquerade as spectral or decay proof.
    private static func velocityExpressionEvidence(
        mono: [Double],
        windows: [UpperVelocityExpressionWindow],
        sampleRate: Double
    ) -> [UpperVelocityExpressionEvidence] {
        let rateIsValid = sampleRate.isFinite && sampleRate > 0
        let effectiveRate = max(1, sampleRate)
        let regionFrames = max(
            16,
            min(2_048, Int((effectiveRate * 0.04).rounded()))
        )
        let maximumWindowFrames = max(
            regionFrames * 2,
            min(maximumFrames, Int((effectiveRate * 0.18).rounded()))
        )
        let highPassCutoff = min(2_400, effectiveRate * 0.22)
        let lowPassCoefficient = 1 - exp(
            -2 * Double.pi * highPassCutoff / effectiveRate
        )

        return windows.map { window in
            let metadataValid = window.velocity.isFinite &&
                window.appliedStartFrequency.isFinite &&
                window.spectralEnvelopeScale.isFinite && window.decayScale.isFinite &&
                window.velocity >= 0 && window.velocity <= 1 &&
                window.appliedStartFrequency > 0 &&
                window.spectralEnvelopeScale >= 0.40 &&
                window.spectralEnvelopeScale <= 1.60 &&
                window.decayScale >= 0.80 && window.decayScale <= 1.20
            let framesValid = window.onsetFrame >= 0 &&
                window.onsetFrame < mono.count &&
                window.endFrame >= window.onsetFrame &&
                window.endFrame <= mono.count
            let start = min(mono.count, max(0, window.onsetFrame))
            let requestedEnd = min(mono.count, max(start, window.endFrame))
            let end = min(requestedEnd, start + maximumWindowFrames)
            let analyzedFrames = max(0, end - start)
            let geometryComplete = rateIsValid && metadataValid && framesValid &&
                analyzedFrames >= regionFrames * 2

            var sourceEnergy = 0.0
            if end > start {
                for frame in start..<end {
                    sourceEnergy += mono[frame] * mono[frame]
                }
            }
            let sourceRMS = analyzedFrames > 0
                ? sqrt(sourceEnergy / Double(analyzedFrames)) : 0

            var attackEnergy = 0.0
            var attackHighEnergy = 0.0
            var tailEnergy = 0.0
            if geometryComplete {
                let attackEnd = start + regionFrames
                var low = mono[start]
                for frame in start..<attackEnd {
                    let sample = mono[frame]
                    low += (sample - low) * lowPassCoefficient
                    let high = sample - low
                    attackEnergy += sample * sample
                    attackHighEnergy += high * high
                }
                let tailStart = end - regionFrames
                for frame in tailStart..<end {
                    let sample = mono[frame]
                    tailEnergy += sample * sample
                }
            }
            let attackRMS = sqrt(attackEnergy / Double(regionFrames))
            let tailRMS = sqrt(tailEnergy / Double(regionFrames))
            let complete = geometryComplete && sourceRMS > epsilon &&
                attackRMS > epsilon
            let highRatio = complete
                ? min(1, max(0, attackHighEnergy / max(epsilon, attackEnergy))) : 0
            let tailToAttack = complete
                ? min(120, max(-120, 20 * log10(max(tailRMS, epsilon) / attackRMS))) : 0

            return UpperVelocityExpressionEvidence(
                onsetFrame: start,
                analyzedEndFrame: end,
                analyzedFrameCount: analyzedFrames,
                velocity: metadataValid ? window.velocity : 0,
                appliedStartFrequency: metadataValid
                    ? window.appliedStartFrequency : 0,
                spectralEnvelopeScale: metadataValid
                    ? window.spectralEnvelopeScale : 0,
                decayScale: metadataValid ? window.decayScale : 0,
                sourceRMS: finiteValue(sourceRMS),
                attackHighBandRatio: finiteValue(highRatio),
                tailToAttackDB: finiteValue(tailToAttack),
                complete: complete
            )
        }
    }

    private static func contrastDB(accented: [Double], unaccented: [Double]) -> Double {
        guard !accented.isEmpty, !unaccented.isEmpty else { return 0 }
        let accent = accented.reduce(0, +) / Double(accented.count)
        let plain = unaccented.reduce(0, +) / Double(unaccented.count)
        guard accent > epsilon, plain > epsilon else { return 0 }
        return min(60, max(-60, 20 * log10(accent / plain)))
    }

    private static func filterContour(mono: [Double], onsetFrames: [Int],
                                      sampleRate: Double) -> (rise: Double, decay: Double) {
        guard !onsetFrames.isEmpty else {
            return filterContourWindow(mono, sampleRate: sampleRate)
        }
        let windowFrames = max(32, min(
            mono.count,
            Int((sampleRate * 0.18).rounded())
        ))
        let contours = onsetFrames.compactMap { onset -> (Double, Double)? in
            let end = min(mono.count, onset + windowFrames)
            guard end - onset >= 16 else { return nil }
            let result = filterContourWindow(
                Array(mono[onset..<end]),
                sampleRate: sampleRate
            )
            return (result.rise, result.decay)
        }
        guard !contours.isEmpty else { return (0, 0) }
        return (
            contours.reduce(0) { $0 + $1.0 } / Double(contours.count),
            contours.reduce(0) { $0 + $1.1 } / Double(contours.count)
        )
    }

    private static func filterContourWindow(_ mono: [Double], sampleRate: Double)
        -> (rise: Double, decay: Double) {
        let block = max(16, min(256, Int((sampleRate * 0.01).rounded())))
        guard mono.count >= block else { return (0, 0) }
        var trajectory: [Double] = []
        var start = 0
        while start + block <= mono.count {
            var energy = 0.0
            var differenceEnergy = 0.0
            for index in start..<(start + block) {
                let sample = mono[index]
                energy += sample * sample
                if index > start {
                    let difference = sample - mono[index - 1]
                    differenceEnergy += difference * difference
                }
            }
            trajectory.append(min(1, differenceEnergy / max(epsilon, energy * 4)))
            start += block
        }
        guard let peak = trajectory.max(), let first = trajectory.first, let last = trajectory.last else {
            return (0, 0)
        }
        return (max(0, peak - first), max(0, peak - last))
    }

    private static func detuneMotion(mono: [Double], sampleRate: Double) -> (depth: Double, period: Double) {
        let block = max(16, min(512, Int((sampleRate * 0.01).rounded())))
        guard mono.count >= block * 8 else { return (0, 0) }
        var envelope: [Double] = []
        var start = 0
        while start + block <= mono.count {
            let energy = mono[start..<(start + block)].reduce(0.0) { $0 + $1 * $1 }
            envelope.append(sqrt(energy / Double(block)))
            start += block
        }
        let sorted = envelope.sorted()
        let low = percentile(sorted, 0.10)
        let high = percentile(sorted, 0.90)
        let depth = high > epsilon ? min(1, max(0, (high - low) / high)) : 0
        guard depth > 0.01 else { return (depth, 0) }

        let mean = envelope.reduce(0, +) / Double(envelope.count)
        let centered = envelope.map { $0 - mean }
        let frameDuration = Double(block) / sampleRate
        var bestPower = 0.0
        var bestFrequency = 0.0
        if centered.count >= 8 {
            for bin in 1...(centered.count / 2) {
                let frequency = Double(bin) / (Double(centered.count) * frameDuration)
                guard frequency >= 0.5, frequency <= 20 else { continue }
                var real = 0.0
                var imaginary = 0.0
                for (index, value) in centered.enumerated() {
                    let angle = 2 * Double.pi * Double(bin * index) / Double(centered.count)
                    real += value * cos(angle)
                    imaginary -= value * sin(angle)
                }
                let power = real * real + imaginary * imaginary
                if power > bestPower {
                    bestPower = power
                    bestFrequency = frequency
                }
            }
        }
        return (depth, bestFrequency > 0 && bestPower > epsilon ? 1 / bestFrequency : 0)
    }

    private struct SpectrumSummary {
        let highRatio: Double
        let aliasRatio: Double
        let bands: [Double]
    }

    private static func spectralSummary(_ samples: [Double], sampleRate: Double) -> SpectrumSummary {
        let limit = min(spectralFrameLimit, samples.count)
        guard limit >= 16 else {
            return SpectrumSummary(highRatio: 0, aliasRatio: 0, bands: Array(repeating: 0, count: 5))
        }
        var count = 1
        while count * 2 <= limit { count *= 2 }
        let start = (samples.count - count) / 2
        let input = Array(samples[start..<(start + count)])
        var real = [Double](repeating: 0, count: count)
        var imaginary = [Double](repeating: 0, count: count)
        for index in 0..<count {
            let window = 0.5 - 0.5 * cos(
                2 * Double.pi * Double(index) / Double(max(1, count - 1))
            )
            real[index] = input[index] * window
        }
        var reversed = 0
        for index in 1..<count {
            var bit = count >> 1
            while reversed & bit != 0 {
                reversed ^= bit
                bit >>= 1
            }
            reversed ^= bit
            if index < reversed {
                real.swapAt(index, reversed)
                imaginary.swapAt(index, reversed)
            }
        }
        var length = 2
        while length <= count {
            let angle = -2 * Double.pi / Double(length)
            let rootReal = cos(angle)
            let rootImaginary = sin(angle)
            let half = length / 2
            var blockStart = 0
            while blockStart < count {
                var weightReal = 1.0
                var weightImaginary = 0.0
                for offset in 0..<half {
                    let even = blockStart + offset
                    let odd = even + half
                    let oddReal = real[odd] * weightReal -
                        imaginary[odd] * weightImaginary
                    let oddImaginary = real[odd] * weightImaginary +
                        imaginary[odd] * weightReal
                    let evenReal = real[even]
                    let evenImaginary = imaginary[even]
                    real[even] = evenReal + oddReal
                    imaginary[even] = evenImaginary + oddImaginary
                    real[odd] = evenReal - oddReal
                    imaginary[odd] = evenImaginary - oddImaginary
                    let nextWeightReal = weightReal * rootReal -
                        weightImaginary * rootImaginary
                    weightImaginary = weightReal * rootImaginary +
                        weightImaginary * rootReal
                    weightReal = nextWeightReal
                }
                blockStart += length
            }
            length *= 2
        }
        let nyquist = sampleRate * 0.5
        let highCutoff = min(8_000, nyquist * 0.5)
        let aliasCutoff = nyquist * 0.8
        var total = 0.0
        var high = 0.0
        var alias = 0.0
        var bands = Array(repeating: 0.0, count: 5)
        for bin in 1...(count / 2) {
            let power = real[bin] * real[bin] + imaginary[bin] * imaginary[bin]
            let frequency = Double(bin) * sampleRate / Double(count)
            total += power
            if frequency >= highCutoff { high += power }
            if frequency >= aliasCutoff { alias += power }
            let bandIndex: Int
            switch frequency {
            case ..<120: bandIndex = 0
            case ..<420: bandIndex = 1
            case ..<2_400: bandIndex = 2
            case ..<8_000: bandIndex = 3
            default: bandIndex = 4
            }
            bands[bandIndex] += power
        }
        guard total > epsilon else {
            return SpectrumSummary(highRatio: 0, aliasRatio: 0, bands: Array(repeating: 0, count: 5))
        }
        return SpectrumSummary(
            highRatio: min(1, max(0, high / total)),
            aliasRatio: min(1, max(0, alias / total)),
            bands: bands.map { $0 / total }
        )
    }

    private static func maskingOverlap(_ first: [Double], _ second: [Double]) -> Double {
        guard first.count == second.count, first.contains(where: { $0 > epsilon }),
              second.contains(where: { $0 > epsilon }) else { return 0 }
        let shared = zip(first, second).reduce(0.0) { $0 + min($1.0, $1.1) }
        let occupied = zip(first, second).reduce(0.0) { $0 + max($1.0, $1.1) }
        return occupied > epsilon ? min(1, max(0, shared / occupied)) : 0
    }

    private static func maximumBoundaryDelta(
        left: [Double],
        right: [Double],
        preceding: UpperTimbreStereoFrame?,
        following: UpperTimbreStereoFrame?
    ) -> Double {
        guard let firstLeft = left.first, let firstRight = right.first,
              let lastLeft = left.last, let lastRight = right.last else { return 0 }
        var result = 0.0
        if let preceding {
            result = max(
                result,
                abs(firstLeft - Double(preceding.left)),
                abs(firstRight - Double(preceding.right))
            )
        }
        if let following {
            result = max(
                result,
                abs(Double(following.left) - lastLeft),
                abs(Double(following.right) - lastRight)
            )
        }
        return result
    }

    private static func percentile(_ sorted: [Double], _ value: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * value).rounded())))
        return sorted[index]
    }

    private static func finiteValue(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static func saturatingAdd(_ left: Int, _ right: Int) -> Int {
        let value = max(0, right)
        return left > Int.max - value ? Int.max : left + value
    }
}

/// Versioned report for one private canonical-journey checkpoint. The default
/// decision is intentionally unavailable until a calibrated policy is supplied.
package enum CanonicalJourneyQualificationReportError: Error, Equatable, Sendable {
    case emptyIdentity
    case schemaMismatch
    case policyMismatch
    case evidenceFingerprintMismatch
    case outgoingDecisionMismatch
    case reasonCodeMismatch
    case invalidBounds
    case missingCalibratedDecision
    case acceptanceProvenanceMismatch
    case outgoingObservationMismatch
    case candidateFingerprintMismatch
    case candidateEvaluationMismatch
    case selectedCandidateEvidenceMismatch
    case routeMismatch
    case checkpointMismatch
}

package struct CanonicalJourneyQualificationReport: Encodable, Equatable, Sendable {
    package static let currentEvidenceScope =
        "candidate-structural-bs1770-signal-role-upper-commit.v2"
    package static let maximumEncodedBytes = 4 * 1_024 * 1_024
    package let schemaVersion: Int
    package let engineVersion: String
    package let policyVersion: String
    package let fixtureFingerprint: String
    package let continuationFingerprint: String
    package let checkpoint: CanonicalJourneyCheckpoint
    package let sampleRate: Double
    package let routeFingerprint: String
    package let routeGeneration: Int
    package let selectedCandidateEvidence: AutonomousCandidateEvaluationVector
    package let candidateEvaluation: AutonomousCandidateEvaluationTransaction
    package let commitProvenance: AutonomousPreparedCommitProvenance
    package let selectedCandidateEvidenceFingerprint: String
    package let evidence: UpperTimbreEvidence
    package let evidenceScope: String
    package let evidenceFingerprint: String
    package let sampleHash: String
    package let reasonCodes: [QualityReasonCode]
    package let decision: QualityDecision
    package let incomingState: QualityContinuationState
    package let outgoingState: QualityContinuationState
    package let usedAlternate: Bool
    package let usedFallback: Bool
    package let usedHomeTimbreFallback: Bool
    package let correctionRenderCount: Int

    /// Decode-only wire value. Keeping `Decodable` off the validated report
    /// prevents package callers from bypassing the size, causality, and
    /// canonical-byte checks with a plain `JSONDecoder`.
    private struct DecodedWire: Codable {
        let schemaVersion: Int
        let engineVersion: String
        let policyVersion: String
        let fixtureFingerprint: String
        let continuationFingerprint: String
        let checkpoint: CanonicalJourneyCheckpoint
        let sampleRate: Double
        let routeFingerprint: String
        let routeGeneration: Int
        let selectedCandidateEvidence: AutonomousCandidateEvaluationVector
        let candidateEvaluation: AutonomousCandidateEvaluationTransaction
        let commitProvenance: AutonomousPreparedCommitProvenance
        let selectedCandidateEvidenceFingerprint: String
        let evidence: UpperTimbreEvidence
        let evidenceScope: String
        let evidenceFingerprint: String
        let sampleHash: String
        let reasonCodes: [QualityReasonCode]
        let decision: QualityDecision
        let incomingState: QualityContinuationState
        let outgoingState: QualityContinuationState
        let usedAlternate: Bool
        let usedFallback: Bool
        let usedHomeTimbreFallback: Bool
        let correctionRenderCount: Int
    }

    package init(
        engineVersion: String,
        policyVersion: String = QualityQualificationContract.uncalibratedPolicyVersion,
        fixtureFingerprint: String,
        continuationFingerprint: String,
        checkpoint: CanonicalJourneyCheckpoint,
        routeFingerprint: String,
        routeGeneration: Int,
        selectedCandidateEvidence: AutonomousCandidateEvaluationVector,
        candidateEvaluation: AutonomousCandidateEvaluationTransaction,
        commitProvenance: AutonomousPreparedCommitProvenance? = nil,
        sampleHash: String,
        decision: QualityDecision? = nil,
        incomingState: QualityContinuationState = QualityContinuationState(),
        outgoingState: QualityContinuationState? = nil,
        usedAlternate: Bool = false,
        usedFallback: Bool = false,
        usedHomeTimbreFallback: Bool = false,
        correctionRenderCount: Int = 0
    ) throws {
        let evidence = selectedCandidateEvidence.postGraphUpperTimbreEvidence
        guard selectedCandidateEvidence.recordIsStructurallyValid,
              candidateEvaluation.attempts.count <=
                AutonomousCandidateEvaluationTransaction.maximumAttemptCount,
              candidateEvaluation.sourceAttemptCount ==
                candidateEvaluation.attempts.count else {
            throw CanonicalJourneyQualificationReportError.invalidBounds
        }
        let transactionFingerprint = candidateEvaluation.fingerprint
        guard !policyVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CanonicalJourneyQualificationReportError.emptyIdentity
        }
        guard policyVersion == QualityQualificationContract.uncalibratedPolicyVersion ||
                decision != nil else {
            throw CanonicalJourneyQualificationReportError.missingCalibratedDecision
        }
        let retainedSelectedAttempt = candidateEvaluation.selectedAttemptIndex.flatMap {
            candidateEvaluation.attempts.indices.contains($0)
                ? candidateEvaluation.attempts[$0] : nil
        }
        var defaultReasons: [QualityReasonCode] = [.policyUncalibratedV1] +
            (retainedSelectedAttempt?.reasonCodes ?? [])
        if candidateEvaluation.selectedSlot == .fallback {
            defaultReasons.append(.conservativeFallbackV1)
        }
        if selectedCandidateEvidence.routeContinuation.routeRecovery {
            defaultReasons.append(.routeRecoveryV1)
        }
        let selectedDecision = decision ?? QualityDecision(
            policyVersion: policyVersion,
            outcome: .qualificationUnavailable,
            reasonCodes: defaultReasons,
            candidateFingerprint: sampleHash,
            evidenceFingerprint: transactionFingerprint
        )
        let selectedOutgoing = outgoingState ?? incomingState.recording(
            decision: selectedDecision,
            evidenceFingerprint: transactionFingerprint,
            controllerStateFingerprint:
                selectedCandidateEvidence.routeContinuation
                    .controllerStateFingerprint
        )
        let selectedCommitProvenance = commitProvenance ??
            AutonomousPreparedCommitProvenance(
                candidateEvaluationFingerprint: transactionFingerprint,
                selectedSampleHash: sampleHash,
                outgoingRenderDSPFingerprint:
                    selectedCandidateEvidence.routeContinuation
                        .outgoingRenderDSPFingerprint,
                qualityState: selectedOutgoing
            )
        guard !engineVersion.isEmpty, !fixtureFingerprint.isEmpty,
              !continuationFingerprint.isEmpty, !routeFingerprint.isEmpty,
              !sampleHash.isEmpty,
              !selectedDecision.policyVersion.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty else {
            throw CanonicalJourneyQualificationReportError.emptyIdentity
        }
        guard evidence.schemaVersion == UpperTimbreEvidenceAnalyzer.schemaVersion,
              selectedCandidateEvidence.schemaVersion ==
                AutonomousCandidateEvaluationVector.schemaVersion,
              candidateEvaluation.schemaVersion ==
                AutonomousCandidateEvaluationTransaction.schemaVersion,
              selectedDecision.schemaVersion == QualityQualificationContract.schemaVersion,
              selectedDecision.reasonCodeVersion ==
                QualityQualificationContract.reasonCodeVersion,
              incomingState.schemaVersion ==
                QualityQualificationContract.schemaVersion,
              selectedOutgoing.schemaVersion ==
                QualityQualificationContract.schemaVersion,
              selectedDecision.isStructurallyValid,
              incomingState.acceptanceProvenanceComplete,
              selectedOutgoing.isStructurallyValid else {
            throw CanonicalJourneyQualificationReportError.schemaMismatch
        }
        guard candidateEvaluation.isComplete,
              let selectedIndex = candidateEvaluation.selectedAttemptIndex,
              candidateEvaluation.attempts.indices.contains(selectedIndex),
              candidateEvaluation.attempts[selectedIndex].vector ==
                selectedCandidateEvidence,
              candidateEvaluation.engineVersion == engineVersion else {
            throw CanonicalJourneyQualificationReportError.candidateEvaluationMismatch
        }
        let symbolic = selectedCandidateEvidence.symbolic
        let checkpointMatches = AutonomousPhraseKind(
            rawValue: symbolic.phraseKind
        ).map {
            CanonicalJourneyCheckpoint.applicable(
                phraseIndex: symbolic.phraseIndex,
                phraseKind: $0,
                chapterChanged: symbolic.chapterChanged
            ).contains(checkpoint)
        } ?? false
        guard checkpointMatches else {
            throw CanonicalJourneyQualificationReportError.checkpointMismatch
        }
        let selectedAttempt = candidateEvaluation.attempts[selectedIndex]
        var requiredAttemptReasons = Set(selectedAttempt.reasonCodes)
        if candidateEvaluation.selectedSlot == .fallback {
            requiredAttemptReasons.insert(.conservativeFallbackV1)
        }
        guard requiredAttemptReasons.isSubset(of: Set(selectedDecision.reasonCodes)) else {
            throw CanonicalJourneyQualificationReportError.reasonCodeMismatch
        }
        if candidateEvaluation.evaluatorVersion ==
            QualityQualificationContract.uncalibratedEvaluatorVersion {
            var exactReasons = Set(selectedAttempt.reasonCodes)
            exactReasons.insert(.policyUncalibratedV1)
            if candidateEvaluation.selectedSlot == .fallback {
                exactReasons.insert(.conservativeFallbackV1)
            }
            if selectedCandidateEvidence.routeContinuation.routeRecovery {
                exactReasons.insert(.routeRecoveryV1)
            }
            guard Set(selectedDecision.reasonCodes) == exactReasons else {
                throw CanonicalJourneyQualificationReportError.reasonCodeMismatch
            }
        }
        let reportsFallback = selectedDecision.reasonCodes.contains(
            .conservativeFallbackV1
        )
        let reportsHold = selectedDecision.reasonCodes.contains(.deterministicHoldV1)
        let reportsRouteRecovery = selectedDecision.reasonCodes.contains(
            .routeRecoveryV1
        )
        let reportsHardGateFailure = selectedDecision.reasonCodes.contains(
            .hardGateFailedV1
        )
        let reportsStaleEvidence = selectedDecision.reasonCodes.contains(
            .staleEvidenceV1
        )
        guard reportsFallback == (candidateEvaluation.selectedSlot == .fallback),
              reportsRouteRecovery == selectedCandidateEvidence
                .routeContinuation.routeRecovery,
              !reportsRouteRecovery || !reportsStaleEvidence,
              reportsHardGateFailure == !selectedCandidateEvidence.hardGatesPassed,
              !reportsHold else {
            throw CanonicalJourneyQualificationReportError.reasonCodeMismatch
        }
        guard selectedDecision.policyVersion !=
                QualityQualificationContract.uncalibratedPolicyVersion ||
                selectedDecision.outcome == .qualificationUnavailable,
              policyVersion == selectedDecision.policyVersion,
              selectedOutgoing.policyVersion == selectedDecision.policyVersion,
              candidateEvaluation.policyVersion == selectedDecision.policyVersion else {
            throw CanonicalJourneyQualificationReportError.policyMismatch
        }
        guard selectedCandidateEvidence.fullMix.sampleHash == sampleHash else {
            throw CanonicalJourneyQualificationReportError.selectedCandidateEvidenceMismatch
        }
        guard selectedDecision.evidenceFingerprint == transactionFingerprint else {
            throw CanonicalJourneyQualificationReportError.evidenceFingerprintMismatch
        }
        guard selectedDecision.candidateFingerprint == sampleHash else {
            throw CanonicalJourneyQualificationReportError.candidateFingerprintMismatch
        }
        guard selectedDecision.hasOutcomeConsistentReasonCodes else {
            throw CanonicalJourneyQualificationReportError.reasonCodeMismatch
        }
        let acceptanceOutcome = selectedDecision.isAcceptanceOutcome
        guard !acceptanceOutcome || (!selectedDecision.hasNonCompensableFailureReason &&
            selectedCandidateEvidence.hardGatesPassed) else {
            throw CanonicalJourneyQualificationReportError.reasonCodeMismatch
        }
        let reportsNonFiniteEvidence = selectedDecision.reasonCodes.contains(
            .evidenceNonFiniteV1
        )
        let reportsMissingEvidence = selectedDecision.reasonCodes.contains(
            .evidenceMissingV1
        )
        let evidenceFinite = evidence.finite && selectedCandidateEvidence.isFinite
        let evidencePresent = evidence.analyzedFrameCount > 0 &&
            selectedCandidateEvidence.isComplete
        let knownInvalidEvidenceIsReasoned = evidenceFinite
            ? !reportsNonFiniteEvidence
            : (reportsNonFiniteEvidence &&
                selectedDecision.reasonCodes.contains(.hardGateFailedV1) &&
                selectedDecision.outcome != .qualified &&
                selectedDecision.outcome != .adjusted)
        let knownMissingEvidenceIsReasoned = evidencePresent
            ? !reportsMissingEvidence
            : (reportsMissingEvidence &&
                selectedDecision.reasonCodes.contains(.hardGateFailedV1) &&
                selectedDecision.outcome != .qualified &&
                selectedDecision.outcome != .adjusted)
        guard knownInvalidEvidenceIsReasoned, knownMissingEvidenceIsReasoned else {
            throw CanonicalJourneyQualificationReportError.reasonCodeMismatch
        }
        guard selectedOutgoing.lastDecision == selectedDecision else {
            throw CanonicalJourneyQualificationReportError.outgoingDecisionMismatch
        }
        guard selectedOutgoing.observedCandidateFingerprint ==
                selectedDecision.candidateFingerprint,
              selectedOutgoing.observedEvidenceFingerprint ==
                transactionFingerprint,
              selectedOutgoing.observedControllerStateFingerprint ==
                selectedCandidateEvidence.routeContinuation
                    .controllerStateFingerprint,
              !acceptanceOutcome ||
                selectedOutgoing.acceptedControllerStateFingerprint ==
                    selectedCandidateEvidence.routeContinuation
                        .controllerStateFingerprint else {
            throw CanonicalJourneyQualificationReportError.outgoingObservationMismatch
        }
        let incomingControllerFingerprint =
            AutonomousCandidateFingerprint.automaticMixController(
                kickCorrectionDB: selectedCandidateEvidence.routeContinuation
                    .incomingKickCorrectionDB
            )
        let incomingStateHasNoObservation = incomingState.revision == 0 &&
            incomingState.observedCandidateFingerprint == nil &&
            incomingState.observedEvidenceFingerprint == nil &&
            incomingState.observedControllerStateFingerprint == nil
        let incomingControllerIsCoherent = incomingStateHasNoObservation
            ? selectedCandidateEvidence.routeContinuation.incomingKickCorrectionDB ==
                AutomaticMixBalancer.homeKickCorrectionDB
            : incomingState.observedControllerStateFingerprint ==
                incomingControllerFingerprint
        guard incomingControllerIsCoherent else {
            throw CanonicalJourneyQualificationReportError.outgoingObservationMismatch
        }
        guard selectedCandidateEvidence.routeContinuation
                .incomingQualityStateFingerprint ==
                AutonomousCandidateFingerprint.qualityState(incomingState),
              selectedOutgoing == incomingState.recording(
                decision: selectedDecision,
                evidenceFingerprint: transactionFingerprint,
                controllerStateFingerprint:
                    selectedCandidateEvidence.routeContinuation
                        .controllerStateFingerprint
              ) else {
            throw CanonicalJourneyQualificationReportError.outgoingDecisionMismatch
        }
        guard selectedCommitProvenance.matches(
            candidateEvaluationFingerprint: transactionFingerprint,
            selectedSampleHash: sampleHash,
            outgoingRenderDSPFingerprint:
                selectedCandidateEvidence.routeContinuation
                    .outgoingRenderDSPFingerprint,
            qualityState: selectedOutgoing
        ) else {
            throw CanonicalJourneyQualificationReportError.candidateEvaluationMismatch
        }
        guard !acceptanceOutcome || selectedOutgoing.acceptanceProvenanceComplete else {
            throw CanonicalJourneyQualificationReportError.acceptanceProvenanceMismatch
        }
        guard routeGeneration >= 0,
              correctionRenderCount >= 0,
              correctionRenderCount <=
                QualityQualificationContract.maximumCorrectionRenders else {
            throw CanonicalJourneyQualificationReportError.invalidBounds
        }
        guard routeGeneration ==
                selectedCandidateEvidence.routeContinuation.routeGeneration,
              routeFingerprint ==
                selectedCandidateEvidence.routeContinuation.routeFingerprint,
              selectedCandidateEvidence.routeContinuation.sampleRate ==
                evidence.sampleRate else {
            throw CanonicalJourneyQualificationReportError.routeMismatch
        }
        guard correctionRenderCount == candidateEvaluation.correctionCount,
              usedAlternate ==
                (candidateEvaluation.selectedSlot == .alternate),
              usedFallback ==
                (candidateEvaluation.selectedSlot == .fallback),
              let selectedAttempt = candidateEvaluation.selectedAttemptIndex.map({
                  candidateEvaluation.attempts[$0]
              }),
              usedHomeTimbreFallback ==
                selectedAttempt.forceHomeUpperTimbre else {
            throw CanonicalJourneyQualificationReportError.candidateEvaluationMismatch
        }
        schemaVersion = QualityQualificationContract.schemaVersion
        self.engineVersion = engineVersion
        self.policyVersion = selectedDecision.policyVersion
        self.fixtureFingerprint = fixtureFingerprint
        self.continuationFingerprint = continuationFingerprint
        self.checkpoint = checkpoint
        sampleRate = evidence.sampleRate
        self.routeFingerprint = routeFingerprint
        self.routeGeneration = routeGeneration
        self.selectedCandidateEvidence = selectedCandidateEvidence
        self.candidateEvaluation = candidateEvaluation
        self.commitProvenance = selectedCommitProvenance
        selectedCandidateEvidenceFingerprint = selectedCandidateEvidence.fingerprint
        self.evidence = evidence
        evidenceScope = Self.currentEvidenceScope
        evidenceFingerprint = transactionFingerprint
        self.sampleHash = sampleHash
        reasonCodes = selectedDecision.reasonCodes
        self.decision = selectedDecision
        self.incomingState = incomingState
        self.outgoingState = selectedOutgoing
        self.usedAlternate = usedAlternate
        self.usedFallback = usedFallback
        self.usedHomeTimbreFallback = usedHomeTimbreFallback
        self.correctionRenderCount = correctionRenderCount
    }

    package func deterministicJSON() throws -> Data {
        let data = try Self.canonicalJSON(self)
        guard data.count <= Self.maximumEncodedBytes else {
            throw CanonicalJourneyQualificationReportError.invalidBounds
        }
        return data
    }

    private static func canonicalJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return try encoder.encode(value)
    }

    package static func decodeDeterministicJSON(
        _ data: Data
    ) throws -> CanonicalJourneyQualificationReport {
        guard data.count <= Self.maximumEncodedBytes else {
            throw CanonicalJourneyQualificationReportError.invalidBounds
        }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        let decoded = try decoder.decode(DecodedWire.self, from: data)
        let validated = try Self(
            engineVersion: decoded.engineVersion,
            policyVersion: decoded.policyVersion,
            fixtureFingerprint: decoded.fixtureFingerprint,
            continuationFingerprint: decoded.continuationFingerprint,
            checkpoint: decoded.checkpoint,
            routeFingerprint: decoded.routeFingerprint,
            routeGeneration: decoded.routeGeneration,
            selectedCandidateEvidence: decoded.selectedCandidateEvidence,
            candidateEvaluation: decoded.candidateEvaluation,
            commitProvenance: decoded.commitProvenance,
            sampleHash: decoded.sampleHash,
            decision: decoded.decision,
            incomingState: decoded.incomingState,
            outgoingState: decoded.outgoingState,
            usedAlternate: decoded.usedAlternate,
            usedFallback: decoded.usedFallback,
            usedHomeTimbreFallback: decoded.usedHomeTimbreFallback,
            correctionRenderCount: decoded.correctionRenderCount
        )
        guard try validated.deterministicJSON() == data else {
            throw CanonicalJourneyQualificationReportError.candidateEvaluationMismatch
        }
        return validated
    }
}
