import AutoTechnoCore
import Foundation

package enum EffectCarrierRenderSchema {
    package static let schemaVersion = 1
    package static let schemaIdentifier = "autotechno-effect-carrier-render.v1"
}

package struct EffectCarrierRoleDoseEvidence: Codable, Equatable, Sendable {
    package let role: SynthRole
    package let eligibleNoteCount: Int
    package let dose: Double
    package let translatedTarget: EffectWorldTarget
    package let instrumentEffects: [String]
}

/// Reduced proof for the one bounded role tap at the existing graph-input
/// boundary. No tap PCM crosses detached preparation.
package struct EffectCarrierRenderEvidence: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let schemaIdentifier: String
    package let bar: Int
    package let worldID: UInt64
    package let status: LongHorizonEffectCarrierStatus
    package let carrierRole: SynthRole?
    package let selectedAtPhraseIndex: Int?
    package let active: Bool
    package let carrierDose: Double
    package let nonCarrierDose: Double
    package let roleDoses: [EffectCarrierRoleDoseEvidence]
    package let carrierSampleHash: String
    package let residualSampleHash: String
    package let graphInputSampleHash: String
    package let graphDoseInputSampleHash: String
    package let graphOutputSampleHash: String
    package let finalUpperSampleHash: String
    package let carrierRMS: Double
    package let residualRMS: Double
    package let maximumReconstructionError: Double
    package let bindingComplete: Bool

    package init(neutralBar bar: Int) {
        let zeroHash = ExactPCMFingerprint.stereo(left: [], right: [])
        schemaVersion = EffectCarrierRenderSchema.schemaVersion
        schemaIdentifier = EffectCarrierRenderSchema.schemaIdentifier
        self.bar = bar
        worldID = 0
        status = .unselected
        carrierRole = nil
        selectedAtPhraseIndex = nil
        active = false
        carrierDose = 0
        nonCarrierDose = 0
        roleDoses = []
        carrierSampleHash = zeroHash
        residualSampleHash = zeroHash
        graphInputSampleHash = zeroHash
        graphDoseInputSampleHash = zeroHash
        graphOutputSampleHash = zeroHash
        finalUpperSampleHash = zeroHash
        carrierRMS = 0
        residualRMS = 0
        maximumReconstructionError = 0
        bindingComplete = bar >= 0
    }

    package init(
        bar: Int,
        articulation: LongHorizonEffectCarrierArticulation,
        synthPerformance: SynthPerformanceBar,
        carrierLeft: [Float],
        carrierRight: [Float],
        residualLeft: [Float],
        residualRight: [Float],
        graphInputLeft: [Float],
        graphInputRight: [Float],
        graphDoseInputLeft: [Float],
        graphDoseInputRight: [Float],
        graphOutputLeft: [Float],
        graphOutputRight: [Float],
        finalUpperLeft: [Float],
        finalUpperRight: [Float],
        maximumReconstructionError: Double,
        bindingComplete: Bool
    ) {
        schemaVersion = EffectCarrierRenderSchema.schemaVersion
        schemaIdentifier = EffectCarrierRenderSchema.schemaIdentifier
        self.bar = bar
        worldID = articulation.state.worldID
        status = articulation.state.status
        carrierRole = articulation.state.role
        selectedAtPhraseIndex = articulation.state.selectedAtPhraseIndex
        active = articulation.active
        carrierDose = articulation.carrierDose
        nonCarrierDose = articulation.nonCarrierDose
        roleDoses = SynthRole.allCases.compactMap { role in
            let notes = synthPerformance.upperNotes(for: role)
            guard let assignment = notes.first?.instrument else { return nil }
            return EffectCarrierRoleDoseEvidence(
                role: role,
                eligibleNoteCount: notes.count,
                dose: articulation.dose(for: role),
                translatedTarget: articulation.target(
                    for: role,
                    assignment: assignment
                ),
                instrumentEffects: assignment.effects.map(\.rawValue)
            )
        }
        carrierSampleHash = ExactPCMFingerprint.stereo(
            left: carrierLeft,
            right: carrierRight
        )
        residualSampleHash = ExactPCMFingerprint.stereo(
            left: residualLeft,
            right: residualRight
        )
        graphInputSampleHash = ExactPCMFingerprint.stereo(
            left: graphInputLeft,
            right: graphInputRight
        )
        graphDoseInputSampleHash = ExactPCMFingerprint.stereo(
            left: graphDoseInputLeft,
            right: graphDoseInputRight
        )
        graphOutputSampleHash = ExactPCMFingerprint.stereo(
            left: graphOutputLeft,
            right: graphOutputRight
        )
        finalUpperSampleHash = ExactPCMFingerprint.stereo(
            left: finalUpperLeft,
            right: finalUpperRight
        )
        carrierRMS = Self.stereoRMS(left: carrierLeft, right: carrierRight)
        residualRMS = Self.stereoRMS(left: residualLeft, right: residualRight)
        self.maximumReconstructionError = maximumReconstructionError
        self.bindingComplete = bindingComplete
    }

    package var isComplete: Bool {
        bindingComplete && bar >= 0 &&
            schemaVersion == EffectCarrierRenderSchema.schemaVersion &&
            schemaIdentifier == EffectCarrierRenderSchema.schemaIdentifier &&
            maximumReconstructionError == 0 &&
            [carrierRMS, residualRMS, maximumReconstructionError]
                .allSatisfy { $0.isFinite && $0 >= 0 } &&
            (!active || (status == .active && carrierRole != nil &&
                carrierDose == 1 &&
                nonCarrierDose == LongHorizonEffectCarrierSchema.nonCarrierDose)) &&
            (active || (carrierDose == 0 && nonCarrierDose == 0)) &&
            roleDoses.allSatisfy { evidence in
                evidence.eligibleNoteCount > 0 && evidence.dose.isFinite &&
                    (0...1).contains(evidence.dose)
            }
    }

    private static func stereoRMS(left: [Float], right: [Float]) -> Double {
        let count = min(left.count, right.count)
        guard count > 0 else { return 0 }
        let energy = (0..<count).reduce(0.0) {
            $0 + Double(left[$1]) * Double(left[$1]) +
                Double(right[$1]) * Double(right[$1])
        }
        return sqrt(energy / Double(count * 2))
    }
}

package enum UpperMusicalPumpRenderSchema {
    package static let schemaVersion = 1
    package static let schemaIdentifier = "autotechno-upper-musical-pump-render.v1"
}

package struct UpperMusicalPumpRenderEvidence: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let schemaIdentifier: String
    package let active: Bool
    package let kickAnchorSteps: [Int]
    package let attackFrameCount: Int
    package let releaseFrameCount: Int
    package let requestedMinimumGain: Double
    package let measuredMinimumGain: Double
    package let changedSampleCount: Int
    package let prePumpSampleHash: String
    package let postPumpSampleHash: String
    package let finite: Bool

    package static let neutral = UpperMusicalPumpRenderEvidence(
        active: false,
        kickAnchorSteps: [],
        attackFrameCount: 0,
        releaseFrameCount: 0,
        requestedMinimumGain: 1,
        measuredMinimumGain: 1,
        changedSampleCount: 0,
        prePumpSampleHash: ExactPCMFingerprint.stereo(left: [], right: []),
        postPumpSampleHash: ExactPCMFingerprint.stereo(left: [], right: []),
        finite: true
    )

    package init(
        active: Bool,
        kickAnchorSteps: [Int],
        attackFrameCount: Int,
        releaseFrameCount: Int,
        requestedMinimumGain: Double,
        measuredMinimumGain: Double,
        changedSampleCount: Int,
        prePumpSampleHash: String,
        postPumpSampleHash: String,
        finite: Bool
    ) {
        schemaVersion = UpperMusicalPumpRenderSchema.schemaVersion
        schemaIdentifier = UpperMusicalPumpRenderSchema.schemaIdentifier
        self.active = active
        self.kickAnchorSteps = kickAnchorSteps
        self.attackFrameCount = attackFrameCount
        self.releaseFrameCount = releaseFrameCount
        self.requestedMinimumGain = requestedMinimumGain
        self.measuredMinimumGain = measuredMinimumGain
        self.changedSampleCount = changedSampleCount
        self.prePumpSampleHash = prePumpSampleHash
        self.postPumpSampleHash = postPumpSampleHash
        self.finite = finite
    }

    package var isComplete: Bool {
        finite && schemaVersion == UpperMusicalPumpRenderSchema.schemaVersion &&
            schemaIdentifier == UpperMusicalPumpRenderSchema.schemaIdentifier &&
            requestedMinimumGain.isFinite && measuredMinimumGain.isFinite &&
            (0...1).contains(requestedMinimumGain) &&
            (0...1).contains(measuredMinimumGain) &&
            (active
                ? (!kickAnchorSteps.isEmpty && attackFrameCount > 0 &&
                    releaseFrameCount > attackFrameCount &&
                    changedSampleCount > 0 &&
                    prePumpSampleHash != postPumpSampleHash)
                : (kickAnchorSteps.isEmpty && changedSampleCount == 0 &&
                    prePumpSampleHash == postPumpSampleHash))
    }
}

package enum UpperMusicalPumpProcessor {
    package static func apply(
        left: [Float],
        right: [Float],
        articulation: UpperMusicalPumpArticulation,
        sampleRate: Double,
        bpm: Double
    ) -> (left: [Float], right: [Float], evidence: UpperMusicalPumpRenderEvidence) {
        let count = min(left.count, right.count)
        let preHash = ExactPCMFingerprint.stereo(left: left, right: right)
        guard articulation.isValid, articulation.active, count > 0,
              sampleRate.isFinite, sampleRate > 0, bpm.isFinite, bpm > 0 else {
            return (
                left,
                right,
                UpperMusicalPumpRenderEvidence(
                    active: false,
                    kickAnchorSteps: [],
                    attackFrameCount: 0,
                    releaseFrameCount: 0,
                    requestedMinimumGain: 1,
                    measuredMinimumGain: 1,
                    changedSampleCount: 0,
                    prePumpSampleHash: preHash,
                    postPumpSampleHash: preHash,
                    finite: true
                )
            )
        }
        let beatFrames = sampleRate * 60 / bpm
        let attackFrames = max(1, Int((
            beatFrames * articulation.attackInBeats
        ).rounded()))
        let releaseFrames = max(attackFrames + 1, Int((
            beatFrames * articulation.releaseInBeats
        ).rounded()))
        let stepFrames = Double(count) / 16
        let anchors = articulation.kickAnchorSteps.map {
            min(count - 1, max(0, Int((Double($0) * stepFrames).rounded())))
        }
        var outputLeft = left
        var outputRight = right
        var measuredMinimumGain = 1.0
        var changed = 0
        var finite = true
        for frame in 0..<count {
            var gain = 1.0
            for anchor in anchors where frame >= anchor {
                let elapsed = frame - anchor
                let candidate: Double
                if elapsed <= attackFrames {
                    candidate = 1 - articulation.attenuation *
                        Double(elapsed) / Double(attackFrames)
                } else if elapsed <= attackFrames + releaseFrames {
                    candidate = articulation.minimumGain +
                        articulation.attenuation *
                        Double(elapsed - attackFrames) / Double(releaseFrames)
                } else {
                    candidate = 1
                }
                gain = min(gain, candidate)
            }
            measuredMinimumGain = min(measuredMinimumGain, gain)
            let newLeft = left[frame] * Float(gain)
            let newRight = right[frame] * Float(gain)
            if newLeft.bitPattern != left[frame].bitPattern ||
                newRight.bitPattern != right[frame].bitPattern {
                changed += 1
            }
            outputLeft[frame] = newLeft
            outputRight[frame] = newRight
            finite = finite && newLeft.isFinite && newRight.isFinite && gain.isFinite
        }
        let postHash = ExactPCMFingerprint.stereo(
            left: outputLeft,
            right: outputRight
        )
        return (
            outputLeft,
            outputRight,
            UpperMusicalPumpRenderEvidence(
                active: true,
                kickAnchorSteps: articulation.kickAnchorSteps,
                attackFrameCount: attackFrames,
                releaseFrameCount: releaseFrames,
                requestedMinimumGain: articulation.minimumGain,
                measuredMinimumGain: measuredMinimumGain,
                changedSampleCount: changed,
                prePumpSampleHash: preHash,
                postPumpSampleHash: postHash,
                finite: finite
            )
        )
    }
}
