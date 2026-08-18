import AutoTechnoCore
import Foundation

/// State-free physical-time envelope applied inside the existing bounded
/// upper-percussion event loop. It owns no continuation and allocates no PCM.
package enum UpperPercussionTailDSPContract {
    package static let attackDurationSeconds = 0.008
    package static let clearanceFinalMultiplier: Float = 0.25

    package static func attackFrameCount(
        sampleRate: Double,
        renderedFrameCount: Int
    ) -> Int {
        guard sampleRate.isFinite, sampleRate > 0,
              renderedFrameCount > 0 else {
            return 0
        }
        return min(
            renderedFrameCount,
            max(0, Int((attackDurationSeconds * sampleRate).rounded()))
        )
    }

    package static func multiplier(
        role: UpperPercussionTailRole,
        frame: Int,
        renderedFrameCount: Int,
        sampleRate: Double
    ) -> Float {
        guard role == .foregroundClearance,
              renderedFrameCount > 0 else {
            return 1
        }
        let boundedFrame = min(max(0, frame), renderedFrameCount - 1)
        let attackFrames = attackFrameCount(
            sampleRate: sampleRate,
            renderedFrameCount: renderedFrameCount
        )
        guard boundedFrame >= attackFrames else { return 1 }
        let tailFrameCount = renderedFrameCount - attackFrames
        guard tailFrameCount > 1 else {
            return tailFrameCount == 1 ? clearanceFinalMultiplier : 1
        }
        let progress = Double(boundedFrame - attackFrames) /
            Double(tailFrameCount - 1)
        let eased = 0.5 - 0.5 * cos(.pi * progress)
        return Float(1.0 - 0.75 * eased)
    }

    package static func process(
        sample: Float,
        role: UpperPercussionTailRole,
        frame: Int,
        renderedFrameCount: Int,
        sampleRate: Double
    ) -> Float {
        guard role == .foregroundClearance else { return sample }
        guard sample != 0 else { return sample }
        return sample * multiplier(
            role: role,
            frame: frame,
            renderedFrameCount: renderedFrameCount,
            sampleRate: sampleRate
        )
    }
}

package struct UpperPercussionTailRenderEvidence: Equatable, Sendable {
    package let scoreEventIndex: Int
    package let voice: EnsembleVoice
    package let step: Int
    package let role: UpperPercussionTailRole
    package let eventIntensity: Double
    package let timingOffsetInSteps: Double
    package let relocated: Bool
    package let renderedFrameCount: Int
    package let attackFrameCount: Int
    package let appliedFinalMultiplier: Double
    package let baseSampleHash: String
    package let renderedSampleHash: String
    package let baseAttackSampleHash: String
    package let renderedAttackSampleHash: String
    package let basePeak: Double
    package let renderedPeak: Double
    package let baseRMS: Double
    package let renderedRMS: Double
    package let baseAttackRMS: Double
    package let renderedAttackRMS: Double
    package let baseTailRMS: Double
    package let renderedTailRMS: Double
    package let baseTailToAttackDB: Double
    package let renderedTailToAttackDB: Double
    package let differenceRMS: Double
    package let finite: Bool
}

/// Streaming same-pass reduction used by the three existing upper-percussion
/// voices. It retains scalar energy and exact hashes, never event PCM.
struct UpperPercussionTailEvidenceAccumulator {
    private let articulation: UpperPercussionTailArticulation
    private let event: EnsembleResolvedEvent
    private let timingOffsetInSteps: Double
    private let sampleRate: Double
    private let renderedFrameCount: Int
    private let attackFrames: Int
    private var baseFingerprint: ExactPCMFingerprint.MonoAccumulator
    private var renderedFingerprint: ExactPCMFingerprint.MonoAccumulator
    private var baseAttackFingerprint: ExactPCMFingerprint.MonoAccumulator
    private var renderedAttackFingerprint: ExactPCMFingerprint.MonoAccumulator
    private var basePeak = 0.0
    private var renderedPeak = 0.0
    private var baseEnergy = 0.0
    private var renderedEnergy = 0.0
    private var baseAttackEnergy = 0.0
    private var renderedAttackEnergy = 0.0
    private var baseTailEnergy = 0.0
    private var renderedTailEnergy = 0.0
    private var differenceEnergy = 0.0
    private var samplesAreFinite = true

    init(
        articulation: UpperPercussionTailArticulation,
        event: EnsembleResolvedEvent,
        timingOffsetInSteps: Double,
        sampleRate: Double,
        renderedFrameCount: Int
    ) {
        self.articulation = articulation
        self.event = event
        self.timingOffsetInSteps = timingOffsetInSteps
        self.sampleRate = sampleRate
        self.renderedFrameCount = renderedFrameCount
        attackFrames = UpperPercussionTailDSPContract.attackFrameCount(
            sampleRate: sampleRate,
            renderedFrameCount: renderedFrameCount
        )
        baseFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: renderedFrameCount
        )
        renderedFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: renderedFrameCount
        )
        baseAttackFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: attackFrames
        )
        renderedAttackFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: attackFrames
        )
    }

    mutating func append(frame: Int, base: Float, rendered: Float) {
        baseFingerprint.append(base)
        renderedFingerprint.append(rendered)
        let baseValue = Double(base)
        let renderedValue = Double(rendered)
        let difference = renderedValue - baseValue
        basePeak = max(basePeak, abs(baseValue))
        renderedPeak = max(renderedPeak, abs(renderedValue))
        baseEnergy += baseValue * baseValue
        renderedEnergy += renderedValue * renderedValue
        differenceEnergy += difference * difference
        if frame < attackFrames {
            baseAttackFingerprint.append(base)
            renderedAttackFingerprint.append(rendered)
            baseAttackEnergy += baseValue * baseValue
            renderedAttackEnergy += renderedValue * renderedValue
        } else {
            baseTailEnergy += baseValue * baseValue
            renderedTailEnergy += renderedValue * renderedValue
        }
        samplesAreFinite = samplesAreFinite && base.isFinite && rendered.isFinite
    }

    var evidence: UpperPercussionTailRenderEvidence {
        let frameDenominator = Double(max(1, renderedFrameCount))
        let attackDenominator = Double(max(1, attackFrames))
        let tailDenominator = Double(max(1, renderedFrameCount - attackFrames))
        let baseRMS = sqrt(baseEnergy / frameDenominator)
        let renderedRMS = sqrt(renderedEnergy / frameDenominator)
        let baseAttackRMS = sqrt(baseAttackEnergy / attackDenominator)
        let renderedAttackRMS = sqrt(renderedAttackEnergy / attackDenominator)
        let baseTailRMS = sqrt(baseTailEnergy / tailDenominator)
        let renderedTailRMS = sqrt(renderedTailEnergy / tailDenominator)
        let differenceRMS = sqrt(differenceEnergy / frameDenominator)
        let baseTailToAttackDB = Self.tailToAttackDB(
            tailRMS: baseTailRMS,
            attackRMS: baseAttackRMS
        )
        let renderedTailToAttackDB = Self.tailToAttackDB(
            tailRMS: renderedTailRMS,
            attackRMS: renderedAttackRMS
        )
        let finalMultiplier = Double(
            UpperPercussionTailDSPContract.multiplier(
                role: articulation.role,
                frame: renderedFrameCount - 1,
                renderedFrameCount: renderedFrameCount,
                sampleRate: sampleRate
            )
        )
        let scalars = [
            event.intensity, timingOffsetInSteps, sampleRate, finalMultiplier,
            basePeak, renderedPeak, baseRMS, renderedRMS, baseAttackRMS,
            renderedAttackRMS, baseTailRMS, renderedTailRMS,
            baseTailToAttackDB, renderedTailToAttackDB, differenceRMS,
        ]
        return UpperPercussionTailRenderEvidence(
            scoreEventIndex: articulation.scoreEventIndex,
            voice: articulation.voice,
            step: articulation.step,
            role: articulation.role,
            eventIntensity: event.intensity,
            timingOffsetInSteps: timingOffsetInSteps,
            relocated: event.relocated,
            renderedFrameCount: renderedFrameCount,
            attackFrameCount: attackFrames,
            appliedFinalMultiplier: finalMultiplier,
            baseSampleHash: baseFingerprint.fingerprint,
            renderedSampleHash: renderedFingerprint.fingerprint,
            baseAttackSampleHash: baseAttackFingerprint.fingerprint,
            renderedAttackSampleHash: renderedAttackFingerprint.fingerprint,
            basePeak: basePeak,
            renderedPeak: renderedPeak,
            baseRMS: baseRMS,
            renderedRMS: renderedRMS,
            baseAttackRMS: baseAttackRMS,
            renderedAttackRMS: renderedAttackRMS,
            baseTailRMS: baseTailRMS,
            renderedTailRMS: renderedTailRMS,
            baseTailToAttackDB: baseTailToAttackDB,
            renderedTailToAttackDB: renderedTailToAttackDB,
            differenceRMS: differenceRMS,
            finite: samplesAreFinite && scalars.allSatisfy(\.isFinite)
        )
    }

    private static func tailToAttackDB(
        tailRMS: Double,
        attackRMS: Double
    ) -> Double {
        guard attackRMS > 0 else { return -120 }
        return min(
            120,
            max(-120, 20 * log10(max(tailRMS / attackRMS, 0.000_001)))
        )
    }
}
