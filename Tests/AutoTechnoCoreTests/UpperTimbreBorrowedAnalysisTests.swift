import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

// Frozen actual analyzer from 06d0843, SHA-256 a1ac0ad947fb9c128014c1c0cc054d63ba60eb432735dc519b373c1cf45a0a7c.
// This private comparison oracle never renders or participates in production.
private enum RetainedArrayUpperTimbreAnalyzer {
    /// Version 3 adds bounded, onset-local anchor velocity expression while
    /// retaining version 2's exact protected-rhythm masking reference.
    static let schemaVersion = 3
    /// Covers one canonical 130 BPM bar through 192 kHz without truncation.
    /// Inputs beyond this detached-preparation bound are marked incomplete.
    static let maximumFrames = 524_288
    static let maximumOnsets = 128
    static let maximumMetadataItems = 512
    static let maximumSlideWindows = 64
    static let maximumEvidenceWindows = 64
    static let maximumVelocityExpressionWindows = 128
    static let maximumVelocityExpressionEvents = 512
    private static let spectralFrameLimit = 1_024
    private static let epsilon = 0.000_000_000_001

    static func analyze(_ input: UpperTimbreAnalysisInput,
        observeCapacity: ((Int) -> Void)? = nil) -> UpperTimbreEvidence {
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
        observeCapacity?((left.capacity + right.capacity + protected.capacity +
            mono.capacity + side.capacity) * MemoryLayout<Double>.stride)
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
    static func aggregate(_ evidence: [UpperTimbreEvidence]) -> UpperTimbreEvidence {
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


@Suite("Borrowed upper analysis preserves exact evidence", .serialized)
struct UpperTimbreBorrowedAnalysisTests {
    private func input(rate: Double, frames: Int, mode: Int = 0) -> UpperTimbreAnalysisInput {
        let left = (0..<frames).map { index -> Float in
            let sample = Double(index)
            let envelope = 0.25 + 0.15 * sin(sample * 0.000_7)
            return Float(envelope * sin(sample * 0.017) + 0.03 * cos(sample * 0.39))
        }
        let right = left.enumerated().map { index, value -> Float in
            mode == 1 ? -value : Float(Double(value) * 0.91 + 0.02 * sin(Double(index) * 0.031))
        }
        let protected = left.map { Float(Double($0) * 0.7) }
        let first = min(7, frames), second = min(frames / 3, frames)
        return UpperTimbreAnalysisInput(left: left, right: right, sampleRate: rate,
            accentedOnsetFrames: [first, second, second, -1, frames],
            unaccentedOnsetFrames: [0, min(frames / 2, frames), frames + 1],
            slideWindows: [.init(startFrame: first, endFrame: min(frames, first + 257))],
            detectedAttackFrames: [first, second, second + 1],
            velocityExpressionWindows: [.init(onsetFrame: first, endFrame: frames,
                velocity: 0.61, appliedStartFrequency: 997,
                spectralEnvelopeScale: 1.12, decayScale: 0.9)],
            protectedReferenceMono: mode == 2 ? [] : protected,
            precedingFrame: .init(left: 0.125, right: -0.25),
            followingFrame: .init(left: -0.1, right: 0.17))
    }

    private func requireExact(_ input: UpperTimbreAnalysisInput) throws {
        let actual = UpperTimbreEvidenceAnalyzer.analyze(input)
        let original = RetainedArrayUpperTimbreAnalyzer.analyze(input)
        #expect(actual == original)
        #expect(actual.fingerprint == original.fingerprint)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(actual) == encoder.encode(original))
    }

    @Test("All reduced fields, fingerprint and JSON match the frozen actual array analyzer")
    func exactEvidenceMatrix() throws {
        for rate in [8_000.0, 44_100, 48_000, 192_000] {
            for frames in [0, 1, 15, 16, 255, 256, 1_023, 1_024, 1_025, 4_096] {
                for mode in 0...2 { try requireExact(input(rate: rate, frames: frames, mode: mode)) }
            }
        }
    }

    @Test("Native complete bars preserve source PCM and eliminate five actual Double allocations")
    func nativeBarAllocationAndIdentity() throws {
        for rate in [44_100.0, 48_000] {
            let frames = Int((240 / AutonomousSessionDirector.bpm * rate).rounded())
            let value = input(rate: rate, frames: frames)
            let left = ExactPCMFingerprint.mono(value.left)
            let right = ExactPCMFingerprint.mono(value.right)
            let protected = ExactPCMFingerprint.mono(value.protectedReferenceMono)
            var allocated = 0
            let baseline = RetainedArrayUpperTimbreAnalyzer.analyze(value) { allocated = $0 }
            let actual = UpperTimbreEvidenceAnalyzer.analyze(value)
            #expect(actual == baseline && actual.fingerprint == baseline.fingerprint)
            #expect(allocated >= frames * 5 * MemoryLayout<Double>.stride)
            #expect(ExactPCMFingerprint.mono(value.left) == left)
            #expect(ExactPCMFingerprint.mono(value.right) == right)
            #expect(ExactPCMFingerprint.mono(value.protectedReferenceMono) == protected)
            try requireExact(value)
            print("{\"schema\":\"autotechno-upper-borrowed-capacity-control.v1\",\"sampleRate\":\(Int(rate)),\"frameCount\":\(frames),\"removedFiveDoubleBufferCapacityBytes\":\(allocated),\"fingerprint\":\"\(actual.fingerprint)\",\"completeWorkingSetQualified\":false,\"runtimeActivation\":false}")
        }
    }

    @Test("Invalid, absent, mismatched and over-bound source or metadata preserve exact refusals")
    func invalidAndBoundedInputs() throws {
        let baseline = input(rate: 48_000, frames: 2_048)
        var left = baseline.left
        left[0] = .nan; left[1] = .infinity; left[2] = -.infinity; left[3] = -0.0
        for rate in [0.0, -1, .nan, .infinity, 48_000] {
            for protected in [[], Array(left.prefix(12)), left] {
                let malformed = UpperTimbreAnalysisInput(left: left,
                    right: Array(baseline.right.dropLast()), sampleRate: rate,
                    accentedOnsetFrames: Array(repeating: 16, count: 513),
                    unaccentedOnsetFrames: [-1, 16, 999_999],
                    slideWindows: Array(repeating: .init(startFrame: 0, endFrame: 1_000), count: 65),
                    detectedAttackFrames: [0, 16],
                    velocityExpressionWindows: [.init(onsetFrame: -1, endFrame: 99_999,
                        velocity: 2, appliedStartFrequency: -1,
                        spectralEnvelopeScale: -1, decayScale: 4)],
                    protectedReferenceMono: protected,
                    precedingFrame: .init(left: .nan, right: .infinity),
                    followingFrame: .init(left: -.infinity, right: .nan))
                try requireExact(malformed)
                #expect(!UpperTimbreEvidenceAnalyzer.analyze(malformed).finite)
            }
        }
        for frames in [UpperTimbreEvidenceAnalyzer.maximumFrames,
                       UpperTimbreEvidenceAnalyzer.maximumFrames + 1] {
            try requireExact(input(rate: 192_000, frames: frames))
        }
    }

    @Test("The view changes no public analysis schema, bounds, or resource admission charge")
    func preservesExistingContract() throws {
        #expect(UpperTimbreEvidenceAnalyzer.schemaVersion == RetainedArrayUpperTimbreAnalyzer.schemaVersion)
        #expect(UpperTimbreEvidenceAnalyzer.maximumFrames == RetainedArrayUpperTimbreAnalyzer.maximumFrames)
        #expect(AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount == 128 * 1_024 * 1_024)
        #expect(QualityQualificationContract.maximumRenderPasses == 2)
        for rate in [44_100.0, 48_000] {
            let budget = try #require(AutonomousPreparationResourceBudget(sampleRate: rate, barCount: 16, renderPassCount: 2))
            #expect(budget.scratchPCMByteCount == budget.framesPerBar * 64 * MemoryLayout<Float>.stride)
        }
    }
}
