import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation

enum LiveFeedbackTestSupport {
    static let profileFingerprint = "1111111111111111"
    static let fingerprintQualifiedPolicyVersion = [
        ProfessionalQualityPrimaryEvaluator.policyFamilyVersion,
        "profile-\(profileFingerprint)",
        "adversarial-2222222222222222",
        "holdout-3333333333333333",
    ].joined(separator: ".")

    static func analyze(
        signal: [Float],
        plan: AutonomousPhrasePlan,
        sampleRate: Double,
        routeGeneration: Int = 3,
        controllerRevision: Int = 4,
        playerSampleRange: Range<Int64>? = nil,
        qualityPolicyVersion: String = fingerprintQualifiedPolicyVersion,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> LiveOutputWindowEvidence? {
        let range = playerSampleRange ??
            (80_000..<Int64(80_000 + signal.count))
        return LiveOutputWindowAnalyzer.analyze(
            left: signal,
            right: signal,
            planIdentity: LiveOutputPlanSourceIdentity(plan: plan),
            routeGeneration: routeGeneration,
            controllerRevision: controllerRevision,
            playerSampleRange: range,
            sampleRate: sampleRate,
            captureProvenance: captureProvenance(
                frameCount: signal.count
            ),
            qualityPolicyVersion: qualityPolicyVersion,
            cancellationRequested: cancellationRequested
        )
    }

    static func target(
        evidence: LiveOutputWindowEvidence,
        selectedLoudnessCheckpoint: CanonicalJourneyCheckpoint? = nil,
        selectedTruePeakCheckpoint: CanonicalJourneyCheckpoint? = nil,
        loudnessLowerLUFS: Double? = nil,
        loudnessUpperLUFS: Double? = nil,
        truePeakLowerDBTP: Double? = nil,
        truePeakUpperDBTP: Double? = nil,
        profileFingerprint: String = LiveFeedbackTestSupport.profileFingerprint
    ) -> LiveMasterHeadroomTarget? {
        guard let firstCheckpoint = evidence.applicableCheckpoints.first else {
            return nil
        }
        let resolvedLoudnessLower = loudnessLowerLUFS ??
            evidence.maximumShortTermLoudnessLUFS - 2
        let resolvedLoudnessUpper = loudnessUpperLUFS ??
            evidence.maximumShortTermLoudnessLUFS + 1
        let resolvedTruePeakLower = truePeakLowerDBTP ??
            evidence.truePeakDBTP - 2
        let resolvedTruePeakUpper = truePeakUpperDBTP ??
            evidence.truePeakDBTP + 1
        let candidate = LiveMasterHeadroomTarget(
            schemaVersion: LiveMasterHeadroomTarget.schemaVersion,
            sourceObservationFingerprint: evidence.fingerprint,
            phraseIndex: evidence.phraseIndex,
            planFingerprint: evidence.planFingerprint,
            routeGeneration: evidence.routeGeneration,
            controllerRevision: evidence.controllerRevision,
            playerSampleRange: evidence.playerSampleRange,
            sampleRate: evidence.sampleRate,
            applicableCheckpoints: evidence.applicableCheckpoints,
            selectedLoudnessCheckpoint:
                selectedLoudnessCheckpoint ?? firstCheckpoint,
            selectedTruePeakCheckpoint:
                selectedTruePeakCheckpoint ?? firstCheckpoint,
            analyzerVersion: evidence.analyzerVersion,
            engineVersion: evidence.engineVersion,
            evidenceVersion: evidence.evidenceVersion,
            qualityPolicyVersion: evidence.qualityPolicyVersion,
            evaluatorVersion: evidence.evaluatorVersion,
            controllerPolicyVersion: evidence.controllerPolicyVersion,
            profileVersion:
                ProfessionalQualityPrimaryEvaluator.requiredProfileVersion,
            profileFingerprint: profileFingerprint,
            loudnessLowerLUFS: resolvedLoudnessLower,
            loudnessUpperLUFS: resolvedLoudnessUpper,
            loudnessMidpointLUFS:
                (resolvedLoudnessLower + resolvedLoudnessUpper) / 2,
            truePeakLowerDBTP: resolvedTruePeakLower,
            truePeakUpperDBTP: resolvedTruePeakUpper,
            truePeakMidpointDBTP:
                (resolvedTruePeakLower + resolvedTruePeakUpper) / 2
        )
        return candidate.isStructurallyValid(sourceEvidence: evidence)
            ? candidate
            : nil
    }

    static func captureProvenance(
        frameCount: Int
    ) -> LiveOutputCaptureProvenance {
        let packetCount = (frameCount + 1_023) / 1_024
        let firstSequence: UInt64 = 500
        return LiveOutputCaptureProvenance(
            packetCount: packetCount,
            firstPacketSequence: firstSequence,
            lastPacketSequence:
                firstSequence + UInt64(packetCount - 1),
            droppedPacketDelta: 0,
            rejectedPacketDelta: 0,
            queueCapacity: 256,
            maximumPacketFrameCount: 1_024,
            queueStorageByteCount:
                LiveOutputCaptureProvenance.requiredQueueStorageByteCount,
            consumerScratchByteCount:
                LiveOutputCaptureProvenance.requiredConsumerScratchByteCount,
            activeWindowByteCount:
                frameCount * 2 * MemoryLayout<Float>.stride,
            workingMemoryByteCount:
                LiveOutputCaptureProvenance.requiredQueueStorageByteCount +
                LiveOutputCaptureProvenance.requiredConsumerScratchByteCount +
                frameCount * 2 * MemoryLayout<Float>.stride,
            coveredFrameCount: frameCount,
            sampleDiscontinuityCount: 0,
            gapFrameCount: 0,
            overlapFrameCount: 0
        )
    }
}
