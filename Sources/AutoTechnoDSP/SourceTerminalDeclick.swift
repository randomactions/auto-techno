import AutoTechnoCore
import Foundation

/// One state-free source-local release for bounded percussion windows. It is
/// applied during detached rendering after each voice's intended articulation,
/// never at the master or realtime callback boundary.
package enum SourceTerminalDeclickContract {
    package static let version = "source-terminal-declick.raised-cosine.v1"
    package static let protectedAttackSeconds = 0.008
    package static let upperPercussionFadeSeconds = 0.002
    package static let lowFrequencyFadeSeconds = 0.004

    package static func supports(_ voice: EnsembleVoice) -> Bool {
        switch voice {
        case .kick, .rumble, .clap, .openHat, .metallic:
            true
        default:
            false
        }
    }

    package static func requestedFadeSeconds(for voice: EnsembleVoice) -> Double {
        switch voice {
        case .kick, .rumble:
            lowFrequencyFadeSeconds
        case .clap, .openHat, .metallic:
            upperPercussionFadeSeconds
        default:
            0
        }
    }

    package static func attackFrameCount(
        sampleRate: Double,
        renderedFrameCount: Int
    ) -> Int {
        guard sampleRate.isFinite, sampleRate > 0,
              renderedFrameCount > 0 else { return 0 }
        return min(
            renderedFrameCount,
            max(1, Int((sampleRate * protectedAttackSeconds).rounded()))
        )
    }

    package static func fadeFrameCount(
        voice: EnsembleVoice,
        sampleRate: Double,
        renderedFrameCount: Int
    ) -> Int {
        let seconds = requestedFadeSeconds(for: voice)
        guard seconds > 0, sampleRate.isFinite, sampleRate > 0,
              renderedFrameCount > 0 else { return 0 }
        let attackFrames = attackFrameCount(
            sampleRate: sampleRate,
            renderedFrameCount: renderedFrameCount
        )
        let available = renderedFrameCount - attackFrames
        guard available >= 2 else { return 0 }
        return min(
            available,
            max(2, Int((sampleRate * seconds).rounded()))
        )
    }

    package static func multiplier(
        voice: EnsembleVoice,
        frame: Int,
        renderedFrameCount: Int,
        sampleRate: Double
    ) -> Float {
        let fadeFrames = fadeFrameCount(
            voice: voice,
            sampleRate: sampleRate,
            renderedFrameCount: renderedFrameCount
        )
        guard fadeFrames >= 2, renderedFrameCount > 0 else { return 1 }
        let boundedFrame = min(max(0, frame), renderedFrameCount - 1)
        let fadeStart = renderedFrameCount - fadeFrames
        guard boundedFrame >= fadeStart else { return 1 }
        let progress = Double(boundedFrame - fadeStart) /
            Double(fadeFrames - 1)
        return Float(0.5 + 0.5 * cos(.pi * progress))
    }

    package static func process(
        sample: Float,
        voice: EnsembleVoice,
        frame: Int,
        renderedFrameCount: Int,
        sampleRate: Double
    ) -> Float {
        let gain = multiplier(
            voice: voice,
            frame: frame,
            renderedFrameCount: renderedFrameCount,
            sampleRate: sampleRate
        )
        if gain == 1 { return sample }
        if gain == 0 { return 0 }
        if sample == 0 { return sample }
        return sample * gain
    }
}

/// Same-pass causal evidence for one bounded source event. The implicit sample
/// after the event window is zero, so the terminal deltas directly measure the
/// discontinuity before and after the source-local release.
package struct SourceTerminalDeclickRenderEvidence: Equatable, Sendable {
    package let version: String
    package let scoreEventIndex: Int
    package let voice: EnsembleVoice
    package let step: Int
    package let renderedFrameCount: Int
    package let attackFrameCount: Int
    package let fadeFrameCount: Int
    package let preFadeSampleHash: String
    package let renderedSampleHash: String
    package let preFadeAttackSampleHash: String
    package let renderedAttackSampleHash: String
    package let preFadePeak: Double
    package let renderedPeak: Double
    package let differenceRMS: Double
    package let changedSampleCount: Int
    package let preFadeLastSampleBitPattern: UInt32
    package let renderedLastSampleBitPattern: UInt32
    package let preFadeTerminalDelta: Double
    package let renderedTerminalDelta: Double
    package let finite: Bool

    package func isComplete(sampleRate: Double) -> Bool {
        let expectedAttack = SourceTerminalDeclickContract.attackFrameCount(
            sampleRate: sampleRate,
            renderedFrameCount: renderedFrameCount
        )
        let expectedFade = SourceTerminalDeclickContract.fadeFrameCount(
            voice: voice,
            sampleRate: sampleRate,
            renderedFrameCount: renderedFrameCount
        )
        return version == SourceTerminalDeclickContract.version &&
            scoreEventIndex >= 0 && (0..<16).contains(step) &&
            SourceTerminalDeclickContract.supports(voice) &&
            sampleRate.isFinite && sampleRate > 0 && renderedFrameCount > 0 &&
            attackFrameCount == expectedAttack && fadeFrameCount == expectedFade &&
            fadeFrameCount >= 2 &&
            Self.isFingerprint(preFadeSampleHash) &&
            Self.isFingerprint(renderedSampleHash) &&
            Self.isFingerprint(preFadeAttackSampleHash) &&
            Self.isFingerprint(renderedAttackSampleHash) &&
            preFadeAttackSampleHash == renderedAttackSampleHash &&
            preFadePeak > 0 && renderedPeak > 0 && renderedPeak <= preFadePeak &&
            differenceRMS > 0 && changedSampleCount > 0 &&
            preFadeSampleHash != renderedSampleHash &&
            Float(bitPattern: preFadeLastSampleBitPattern).isFinite &&
            renderedLastSampleBitPattern == 0 &&
            preFadeTerminalDelta == abs(Double(
                Float(bitPattern: preFadeLastSampleBitPattern)
            )) && renderedTerminalDelta.bitPattern == 0 && finite &&
            [preFadePeak, renderedPeak, differenceRMS,
             preFadeTerminalDelta, renderedTerminalDelta]
                .allSatisfy(\.isFinite)
    }

    private static func isFingerprint(_ value: String) -> Bool {
        value.utf8.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

struct SourceTerminalDeclickEvidenceAccumulator {
    private let scoreEventIndex: Int
    private let voice: EnsembleVoice
    private let step: Int
    private let renderedFrameCount: Int
    private let attackFrames: Int
    private let fadeFrames: Int
    private var preFadeFingerprint: ExactPCMFingerprint.MonoAccumulator
    private var renderedFingerprint: ExactPCMFingerprint.MonoAccumulator
    private var preFadeAttackFingerprint: ExactPCMFingerprint.MonoAccumulator
    private var renderedAttackFingerprint: ExactPCMFingerprint.MonoAccumulator
    private var preFadePeak = 0.0
    private var renderedPeak = 0.0
    private var differenceEnergy = 0.0
    private var changedSampleCount = 0
    private var appendedFrameCount = 0
    private var preFadeLastSample: Float = 0
    private var renderedLastSample: Float = 0
    private var finite = true

    init(
        scoreEventIndex: Int,
        voice: EnsembleVoice,
        step: Int,
        sampleRate: Double,
        renderedFrameCount: Int
    ) {
        self.scoreEventIndex = scoreEventIndex
        self.voice = voice
        self.step = step
        self.renderedFrameCount = renderedFrameCount
        attackFrames = SourceTerminalDeclickContract.attackFrameCount(
            sampleRate: sampleRate,
            renderedFrameCount: renderedFrameCount
        )
        fadeFrames = SourceTerminalDeclickContract.fadeFrameCount(
            voice: voice,
            sampleRate: sampleRate,
            renderedFrameCount: renderedFrameCount
        )
        preFadeFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: renderedFrameCount
        )
        renderedFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: renderedFrameCount
        )
        preFadeAttackFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: attackFrames
        )
        renderedAttackFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: attackFrames
        )
        finite = scoreEventIndex >= 0 && SourceTerminalDeclickContract.supports(voice) &&
            renderedFrameCount > 0 && fadeFrames >= 2
    }

    mutating func append(frame: Int, preFade: Float, rendered: Float) {
        preFadeFingerprint.append(preFade)
        renderedFingerprint.append(rendered)
        if frame < attackFrames {
            preFadeAttackFingerprint.append(preFade)
            renderedAttackFingerprint.append(rendered)
        }
        let preValue = Double(preFade)
        let renderedValue = Double(rendered)
        let difference = renderedValue - preValue
        preFadePeak = max(preFadePeak, abs(preValue))
        renderedPeak = max(renderedPeak, abs(renderedValue))
        differenceEnergy += difference * difference
        if preFade.bitPattern != rendered.bitPattern {
            changedSampleCount += 1
        }
        preFadeLastSample = preFade
        renderedLastSample = rendered
        appendedFrameCount += 1
        finite = finite && frame == appendedFrameCount - 1 &&
            preFade.isFinite && rendered.isFinite
    }

    var evidence: SourceTerminalDeclickRenderEvidence {
        let differenceRMS = sqrt(
            differenceEnergy / Double(max(1, renderedFrameCount))
        )
        return SourceTerminalDeclickRenderEvidence(
            version: SourceTerminalDeclickContract.version,
            scoreEventIndex: scoreEventIndex,
            voice: voice,
            step: step,
            renderedFrameCount: renderedFrameCount,
            attackFrameCount: attackFrames,
            fadeFrameCount: fadeFrames,
            preFadeSampleHash: preFadeFingerprint.fingerprint,
            renderedSampleHash: renderedFingerprint.fingerprint,
            preFadeAttackSampleHash: preFadeAttackFingerprint.fingerprint,
            renderedAttackSampleHash: renderedAttackFingerprint.fingerprint,
            preFadePeak: preFadePeak,
            renderedPeak: renderedPeak,
            differenceRMS: differenceRMS,
            changedSampleCount: changedSampleCount,
            preFadeLastSampleBitPattern: preFadeLastSample.bitPattern,
            renderedLastSampleBitPattern: renderedLastSample.bitPattern,
            preFadeTerminalDelta: abs(Double(preFadeLastSample)),
            renderedTerminalDelta: abs(Double(renderedLastSample)),
            finite: finite && appendedFrameCount == renderedFrameCount &&
                differenceRMS.isFinite
        )
    }
}
