import AutoTechnoCore
import Foundation

/// Bounded transport facts supplied by the detached App-owned window
/// assembler. Packet count audits the whole window and may exceed instantaneous
/// queue occupancy; capacity and packet size remain fixed configuration proof.
/// The analyzer never estimates missing capture history.
package struct LiveOutputCaptureProvenance: Equatable, Sendable {
    package static let schemaVersion = 1
    package static let requiredQueueCapacity = 256
    package static let requiredMaximumPacketFrameCount = 1_024
    package static let maximumWorkingMemoryByteCount =
        144_000 * 2 * MemoryLayout<Float>.stride

    package let packetCount: Int
    package let firstPacketSequence: UInt64
    package let lastPacketSequence: UInt64
    package let droppedPacketDelta: UInt64
    package let rejectedPacketDelta: UInt64
    package let queueCapacity: Int
    package let maximumPacketFrameCount: Int
    package let workingMemoryByteCount: Int
    package let coveredFrameCount: Int
    package let sampleDiscontinuityCount: Int
    package let gapFrameCount: Int
    package let overlapFrameCount: Int

    package init(
        packetCount: Int,
        firstPacketSequence: UInt64,
        lastPacketSequence: UInt64,
        droppedPacketDelta: UInt64,
        rejectedPacketDelta: UInt64,
        queueCapacity: Int,
        maximumPacketFrameCount: Int,
        workingMemoryByteCount: Int,
        coveredFrameCount: Int,
        sampleDiscontinuityCount: Int,
        gapFrameCount: Int,
        overlapFrameCount: Int
    ) {
        self.packetCount = packetCount
        self.firstPacketSequence = firstPacketSequence
        self.lastPacketSequence = lastPacketSequence
        self.droppedPacketDelta = droppedPacketDelta
        self.rejectedPacketDelta = rejectedPacketDelta
        self.queueCapacity = queueCapacity
        self.maximumPacketFrameCount = maximumPacketFrameCount
        self.workingMemoryByteCount = workingMemoryByteCount
        self.coveredFrameCount = coveredFrameCount
        self.sampleDiscontinuityCount = sampleDiscontinuityCount
        self.gapFrameCount = gapFrameCount
        self.overlapFrameCount = overlapFrameCount
    }

    package func isComplete(frameCount: Int) -> Bool {
        guard frameCount > 0,
              packetCount > 0,
              packetCount <= frameCount,
              droppedPacketDelta == 0,
              rejectedPacketDelta == 0,
              coveredFrameCount == frameCount,
              sampleDiscontinuityCount == 0,
              gapFrameCount == 0,
              overlapFrameCount == 0,
              queueCapacity == Self.requiredQueueCapacity,
              maximumPacketFrameCount ==
                Self.requiredMaximumPacketFrameCount else {
            return false
        }
        let minimumPacketCount =
            (frameCount + Self.requiredMaximumPacketFrameCount - 1) /
            Self.requiredMaximumPacketFrameCount
        let sequenceDelta = lastPacketSequence.subtractingReportingOverflow(
            firstPacketSequence
        )
        let expectedWorkingMemory = frameCount.multipliedReportingOverflow(
            by: 2 * MemoryLayout<Float>.stride
        )
        return packetCount >= minimumPacketCount &&
            !sequenceDelta.overflow &&
            sequenceDelta.partialValue == UInt64(packetCount - 1) &&
            !expectedWorkingMemory.overflow &&
            workingMemoryByteCount == expectedWorkingMemory.partialValue &&
            workingMemoryByteCount <= Self.maximumWorkingMemoryByteCount
    }
}

/// Canonical musical identity reduced from one immutable director-owned plan.
/// Callers cannot pair a plan fingerprint with separately supplied phrase or
/// chapter semantics because the only constructor derives all of them from
/// the same complete plan.
package struct LiveOutputPlanSourceIdentity: Equatable, Sendable {
    package let planFingerprint: String
    package let phraseIndex: Int
    package let phraseKind: AutonomousPhraseKind
    package let chapterChanged: Bool
    package let applicableCheckpoints: [CanonicalJourneyCheckpoint]

    package init(plan: AutonomousPhrasePlan) {
        planFingerprint = AutonomousTypedFingerprint.plan(plan)
        phraseIndex = plan.phraseIndex
        phraseKind = plan.kind

        let chapters = plan.resolvedBars.map(\.interlockChapter)
        let changesInsidePhrase = zip(
            chapters,
            chapters.dropFirst()
        ).contains { $0 != $1 }
        let beginsAtChapterBoundary = plan.startBar > 0 &&
            plan.startBar.isMultiple(of: 16)
        let changesAtBoundary = beginsAtChapterBoundary &&
            plan.endingInterlockState.previousChapters.last.map {
                $0 != chapters.first
            } == true
        chapterChanged = changesInsidePhrase || changesAtBoundary

        let represented = CanonicalJourneyCheckpoint.applicable(
            phraseIndex: plan.phraseIndex,
            phraseKind: plan.kind,
            chapterChanged: chapterChanged
        )
        applicableCheckpoints = represented.isEmpty
            ? [.longContinuation]
            : represented
    }
}

/// Immutable, signal-free evidence reduced from one complete app-owned mixer
/// window on the detached live-feedback worker. Silence remains complete but
/// is explicitly inactive, so it cannot be mistaken for recovery evidence.
package struct LiveOutputWindowEvidence: Equatable, Sendable {
    package static let schemaVersion = 1

    package let schemaVersion: Int
    package let analyzerVersion: String
    package let engineVersion: String
    package let evidenceVersion: String
    package let qualityPolicyVersion: String
    package let evaluatorVersion: String
    package let controllerPolicyVersion: String
    package let phraseIndex: Int
    package let planFingerprint: String
    package let phraseKind: AutonomousPhraseKind
    package let chapterChanged: Bool
    package let routeGeneration: Int
    package let controllerRevision: Int
    package let playerSampleRange: Range<Int64>
    package let sampleRate: Double
    package let frameCount: Int
    package let applicableCheckpoints: [CanonicalJourneyCheckpoint]
    package let captureProvenance: LiveOutputCaptureProvenance
    package let captureBounded: Bool
    package let pcmFingerprint: String
    package let integratedLoudnessLUFS: Double
    package let maximumMomentaryLoudnessLUFS: Double
    package let maximumShortTermLoudnessLUFS: Double
    package let loudnessRangeLU: Double
    package let momentaryBlockCount: Int
    package let absoluteGatedBlockCount: Int
    package let relativeGatedBlockCount: Int
    package let shortTermBlockCount: Int
    package let loudnessMaximumBufferedFrameCount: Int
    package let loudnessPeakWorkingByteCount: Int
    package let leftTruePeakLinear: Double
    package let rightTruePeakLinear: Double
    package let maximumTruePeakLinear: Double
    package let leftTruePeakDBTP: Double
    package let rightTruePeakDBTP: Double
    package let truePeakDBTP: Double
    package let isActiveProgram: Bool
    package let complete: Bool

    package var fingerprint: String {
        AutonomousTypedFingerprint.liveOutputWindowEvidence(self)
    }

    package var isStructurallyValid: Bool {
        guard schemaVersion == Self.schemaVersion,
              analyzerVersion == LiveOutputWindowAnalyzer.analyzerVersion,
              engineVersion == QualityQualificationContract.engineVersion,
              evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion,
              qualityPolicyVersion ==
                LiveOutputWindowAnalyzer.expectedQualityPolicyVersion,
              evaluatorVersion == ProfessionalQualityPrimaryEvaluator
                .evaluatorVersionIdentifier,
              controllerPolicyVersion ==
                LiveOutputWindowAnalyzer.controllerPolicyVersion,
              phraseIndex >= 0,
              routeGeneration >= 0,
              controllerRevision >= 0,
              !planFingerprint.isEmpty,
              planFingerprint.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ) == planFingerprint,
              let requiredFrameCount = LiveOutputWindowAnalyzer.frameCount(
                  sampleRate: sampleRate
              ),
              frameCount == requiredFrameCount,
              playerSampleRange.lowerBound >= 0,
              playerSampleRange.upperBound - playerSampleRange.lowerBound ==
                Int64(frameCount),
              applicableCheckpoints == expectedApplicableCheckpoints,
              !applicableCheckpoints.isEmpty,
              Set(applicableCheckpoints).count == applicableCheckpoints.count,
              captureProvenance.isComplete(frameCount: frameCount),
              captureBounded,
              integratedLoudnessLUFS.isFinite,
              maximumMomentaryLoudnessLUFS.isFinite,
              maximumShortTermLoudnessLUFS.isFinite,
              loudnessRangeLU.isFinite,
              momentaryBlockCount == 27,
              shortTermBlockCount == 1,
              absoluteGatedBlockCount >= 0,
              absoluteGatedBlockCount <= momentaryBlockCount,
              relativeGatedBlockCount >= 0,
              relativeGatedBlockCount <= absoluteGatedBlockCount,
              loudnessMaximumBufferedFrameCount >= frameCount,
              loudnessPeakWorkingByteCount > 0,
              leftTruePeakLinear.isFinite,
              rightTruePeakLinear.isFinite,
              maximumTruePeakLinear == max(
                  leftTruePeakLinear,
                  rightTruePeakLinear
              ),
              leftTruePeakDBTP == BS1770AudioEvidence.decibelsTruePeak(
                  amplitude: leftTruePeakLinear
              ),
              rightTruePeakDBTP == BS1770AudioEvidence.decibelsTruePeak(
                  amplitude: rightTruePeakLinear
              ),
              truePeakDBTP == BS1770AudioEvidence.decibelsTruePeak(
                  amplitude: maximumTruePeakLinear
              ),
              isActiveProgram == (absoluteGatedBlockCount > 0),
              complete else {
            return false
        }
        return true
    }

    private var expectedApplicableCheckpoints: [CanonicalJourneyCheckpoint] {
        let represented = CanonicalJourneyCheckpoint.applicable(
            phraseIndex: phraseIndex,
            phraseKind: phraseKind,
            chapterChanged: chapterChanged
        )
        return represented.isEmpty ? [.longContinuation] : represented
    }

    fileprivate init(
        analyzerVersion: String,
        engineVersion: String,
        evidenceVersion: String,
        qualityPolicyVersion: String,
        evaluatorVersion: String,
        controllerPolicyVersion: String,
        planIdentity: LiveOutputPlanSourceIdentity,
        routeGeneration: Int,
        controllerRevision: Int,
        playerSampleRange: Range<Int64>,
        sampleRate: Double,
        frameCount: Int,
        captureProvenance: LiveOutputCaptureProvenance,
        pcmFingerprint: String,
        loudness: BS1770LoudnessMeasurement,
        channelPeaks: (left: Double, right: Double)
    ) {
        schemaVersion = Self.schemaVersion
        self.analyzerVersion = analyzerVersion
        self.engineVersion = engineVersion
        self.evidenceVersion = evidenceVersion
        self.qualityPolicyVersion = qualityPolicyVersion
        self.evaluatorVersion = evaluatorVersion
        self.controllerPolicyVersion = controllerPolicyVersion
        phraseIndex = planIdentity.phraseIndex
        planFingerprint = planIdentity.planFingerprint
        phraseKind = planIdentity.phraseKind
        chapterChanged = planIdentity.chapterChanged
        self.routeGeneration = routeGeneration
        self.controllerRevision = controllerRevision
        self.playerSampleRange = playerSampleRange
        self.sampleRate = sampleRate
        self.frameCount = frameCount
        self.applicableCheckpoints = planIdentity.applicableCheckpoints
        self.captureProvenance = captureProvenance
        captureBounded = captureProvenance.isComplete(frameCount: frameCount)
        self.pcmFingerprint = pcmFingerprint
        integratedLoudnessLUFS = loudness.integratedLoudness
        maximumMomentaryLoudnessLUFS = loudness.maximumMomentaryLoudness
        maximumShortTermLoudnessLUFS = loudness.maximumShortTermLoudness
        loudnessRangeLU = loudness.loudnessRange
        momentaryBlockCount = loudness.momentaryBlockCount
        absoluteGatedBlockCount = loudness.absoluteGatedBlockCount
        relativeGatedBlockCount = loudness.relativeGatedBlockCount
        shortTermBlockCount = loudness.shortTermBlockCount
        loudnessMaximumBufferedFrameCount = loudness.maximumBufferedFrameCount
        loudnessPeakWorkingByteCount = loudness.peakWorkingByteCount
        leftTruePeakLinear = channelPeaks.left
        rightTruePeakLinear = channelPeaks.right
        maximumTruePeakLinear = max(channelPeaks.left, channelPeaks.right)
        leftTruePeakDBTP = BS1770AudioEvidence.decibelsTruePeak(
            amplitude: channelPeaks.left
        )
        rightTruePeakDBTP = BS1770AudioEvidence.decibelsTruePeak(
            amplitude: channelPeaks.right
        )
        truePeakDBTP = BS1770AudioEvidence.decibelsTruePeak(
            amplitude: maximumTruePeakLinear
        )
        isActiveProgram = loudness.absoluteGatedBlockCount > 0
        complete = true
    }
}

/// The calibrated controller target is inseparable from the exact observation
/// that selected it. Per-metric checkpoint identity prevents a lower/midpoint
/// from being paired with another checkpoint's stricter upper bound.
package struct LiveMasterHeadroomTarget: Equatable, Sendable {
    package static let schemaVersion = 1

    package let schemaVersion: Int
    package let sourceObservationFingerprint: String
    package let phraseIndex: Int
    package let planFingerprint: String
    package let routeGeneration: Int
    package let controllerRevision: Int
    package let playerSampleRange: Range<Int64>
    package let sampleRate: Double
    package let applicableCheckpoints: [CanonicalJourneyCheckpoint]
    package let selectedLoudnessCheckpoint: CanonicalJourneyCheckpoint
    package let selectedTruePeakCheckpoint: CanonicalJourneyCheckpoint
    package let analyzerVersion: String
    package let engineVersion: String
    package let evidenceVersion: String
    package let qualityPolicyVersion: String
    package let evaluatorVersion: String
    package let controllerPolicyVersion: String
    package let profileVersion: String
    package let profileFingerprint: String
    package let loudnessLowerLUFS: Double
    package let loudnessUpperLUFS: Double
    package let loudnessMidpointLUFS: Double
    package let truePeakLowerDBTP: Double
    package let truePeakUpperDBTP: Double
    package let truePeakMidpointDBTP: Double

    package var fingerprint: String {
        AutonomousTypedFingerprint.liveMasterHeadroomTarget(self)
    }

    package func isStructurallyValid(
        sourceEvidence: LiveOutputWindowEvidence
    ) -> Bool {
        schemaVersion == Self.schemaVersion &&
            sourceEvidence.isStructurallyValid &&
            sourceObservationFingerprint == sourceEvidence.fingerprint &&
            phraseIndex == sourceEvidence.phraseIndex &&
            planFingerprint == sourceEvidence.planFingerprint &&
            routeGeneration == sourceEvidence.routeGeneration &&
            controllerRevision == sourceEvidence.controllerRevision &&
            playerSampleRange == sourceEvidence.playerSampleRange &&
            sampleRate == sourceEvidence.sampleRate &&
            applicableCheckpoints == sourceEvidence.applicableCheckpoints &&
            applicableCheckpoints.contains(selectedLoudnessCheckpoint) &&
            applicableCheckpoints.contains(selectedTruePeakCheckpoint) &&
            analyzerVersion == sourceEvidence.analyzerVersion &&
            engineVersion == sourceEvidence.engineVersion &&
            evidenceVersion == sourceEvidence.evidenceVersion &&
            qualityPolicyVersion == sourceEvidence.qualityPolicyVersion &&
            evaluatorVersion == sourceEvidence.evaluatorVersion &&
            controllerPolicyVersion ==
                sourceEvidence.controllerPolicyVersion &&
            profileVersion ==
                ProfessionalQualityCalibrationProfile.profileVersion &&
            profileFingerprint == ProfessionalQualityPrimaryArtifacts
                .expectedProfileFingerprint &&
            loudnessLowerLUFS.isFinite && loudnessUpperLUFS.isFinite &&
            loudnessLowerLUFS <= loudnessMidpointLUFS &&
            loudnessMidpointLUFS <= loudnessUpperLUFS &&
            loudnessMidpointLUFS ==
                (loudnessLowerLUFS + loudnessUpperLUFS) / 2 &&
            truePeakLowerDBTP.isFinite && truePeakUpperDBTP.isFinite &&
            truePeakLowerDBTP <= truePeakMidpointDBTP &&
            truePeakMidpointDBTP <= truePeakUpperDBTP &&
            truePeakMidpointDBTP ==
                (truePeakLowerDBTP + truePeakUpperDBTP) / 2
    }
}

/// Bounded background-only measurement and target resolution for the first
/// exact three seconds of one scheduled phrase. It owns no callback, queue,
/// transport, controller transition, renderer, or continuation behavior.
package enum LiveOutputWindowAnalyzer {
    package static let analyzerVersion =
        "autotechno-live-output-window-analyzer.v1"
    package static let controllerPolicyVersion =
        "autotechno-live-master-headroom-controller.v1"
    package static let windowDurationSeconds = 3.0
    package static let supportedSampleRates = [44_100.0, 48_000.0]
    package static let expectedQualityPolicyVersion = [
        ProfessionalQualityPrimaryEvaluator.policyFamilyVersion,
        "profile-\(ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint)",
        "adversarial-\(ProfessionalQualityPrimaryArtifacts.expectedAdversarialSuiteFingerprint)",
        "holdout-\(ProfessionalQualityPrimaryArtifacts.expectedHoldoutQualificationFingerprint)",
    ].joined(separator: ".")

    package static func frameCount(sampleRate: Double) -> Int? {
        switch sampleRate {
        case 44_100: return 132_300
        case 48_000: return 144_000
        default: return nil
        }
    }

    package static func analyze(
        left: [Float],
        right: [Float],
        planIdentity: LiveOutputPlanSourceIdentity,
        routeGeneration: Int,
        controllerRevision: Int,
        playerSampleRange: Range<Int64>,
        sampleRate: Double,
        captureProvenance: LiveOutputCaptureProvenance,
        artifacts: ProfessionalQualityPrimaryArtifacts,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> LiveOutputWindowEvidence? {
        guard !cancellationRequested(),
              currentArtifactsAreExact(artifacts),
              let requiredFrameCount = frameCount(sampleRate: sampleRate),
              left.count == requiredFrameCount,
              right.count == requiredFrameCount,
              planIdentity.phraseIndex >= 0,
              routeGeneration >= 0,
              controllerRevision >= 0,
              !planIdentity.planFingerprint.isEmpty,
              planIdentity.planFingerprint.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ) == planIdentity.planFingerprint,
              playerSampleRange.lowerBound >= 0,
              captureProvenance.isComplete(
                  frameCount: requiredFrameCount
              ) else {
            return nil
        }
        let rangeLength = playerSampleRange.upperBound
            .subtractingReportingOverflow(playerSampleRange.lowerBound)
        guard !rangeLength.overflow,
              rangeLength.partialValue == Int64(requiredFrameCount),
              samplesAreFinite(
                  left,
                  cancellationRequested: cancellationRequested
              ),
              samplesAreFinite(
                  right,
                  cancellationRequested: cancellationRequested
              ) else {
            return nil
        }
        guard let loudness = BS1770LoudnessMeasurement(
            left: left,
            right: right,
            sampleRate: sampleRate,
            cancellationRequested: cancellationRequested
        ), let channelPeaks = BS1770AudioEvidence.stereoTruePeak(
            leftChunks: [left],
            rightChunks: [right],
            cancellationRequested: cancellationRequested
        ), loudness.integratedLoudness.isFinite,
           loudness.maximumMomentaryLoudness.isFinite,
           loudness.maximumShortTermLoudness.isFinite,
           loudness.loudnessRange.isFinite,
           loudness.momentaryBlockCount == 27,
           loudness.shortTermBlockCount == 1,
           channelPeaks.left.isFinite,
           channelPeaks.right.isFinite,
           !cancellationRequested(),
           let pcmFingerprint = AutonomousTypedFingerprint.liveOutputPCM(
               left: left,
               right: right,
               cancellationRequested: cancellationRequested
           ),
           !cancellationRequested() else {
            return nil
        }
        let evidence = LiveOutputWindowEvidence(
            analyzerVersion: analyzerVersion,
            engineVersion: QualityQualificationContract.engineVersion,
            evidenceVersion: ProfessionalEvidenceReportBank.evidenceVersion,
            qualityPolicyVersion: expectedQualityPolicyVersion,
            evaluatorVersion: ProfessionalQualityPrimaryEvaluator
                .evaluatorVersionIdentifier,
            controllerPolicyVersion: controllerPolicyVersion,
            planIdentity: planIdentity,
            routeGeneration: routeGeneration,
            controllerRevision: controllerRevision,
            playerSampleRange: playerSampleRange,
            sampleRate: sampleRate,
            frameCount: requiredFrameCount,
            captureProvenance: captureProvenance,
            pcmFingerprint: pcmFingerprint,
            loudness: loudness,
            channelPeaks: channelPeaks
        )
        guard !cancellationRequested(), evidence.isStructurallyValid else {
            return nil
        }
        return evidence
    }

    package static func target(
        evidence: LiveOutputWindowEvidence,
        artifacts: ProfessionalQualityPrimaryArtifacts
    ) -> LiveMasterHeadroomTarget? {
        let profile = artifacts.profile
        guard currentArtifactsAreExact(artifacts),
              evidence.isStructurallyValid,
              evidence.engineVersion == profile.engineVersion,
              evidence.evidenceVersion == profile.evidenceVersion,
              evidence.qualityPolicyVersion == artifacts.evaluator.policyVersion,
              evidence.evaluatorVersion == artifacts.evaluator.evaluatorVersion,
              evidence.sampleRate.isFinite,
              profile.sampleRates.contains(evidence.sampleRate),
              profile.fingerprint ==
                ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint,
              let loudness = strictestBounds(
                  metric: .maximumShortTermLoudnessLUFS,
                  checkpoints: evidence.applicableCheckpoints,
                  profile: profile
              ), let truePeak = strictestBounds(
                  metric: .truePeakDBTP,
                  checkpoints: evidence.applicableCheckpoints,
                  profile: profile
              ) else {
            return nil
        }

        let target = LiveMasterHeadroomTarget(
            schemaVersion: LiveMasterHeadroomTarget.schemaVersion,
            sourceObservationFingerprint: evidence.fingerprint,
            phraseIndex: evidence.phraseIndex,
            planFingerprint: evidence.planFingerprint,
            routeGeneration: evidence.routeGeneration,
            controllerRevision: evidence.controllerRevision,
            playerSampleRange: evidence.playerSampleRange,
            sampleRate: evidence.sampleRate,
            applicableCheckpoints: evidence.applicableCheckpoints,
            selectedLoudnessCheckpoint: loudness.checkpoint,
            selectedTruePeakCheckpoint: truePeak.checkpoint,
            analyzerVersion: evidence.analyzerVersion,
            engineVersion: evidence.engineVersion,
            evidenceVersion: evidence.evidenceVersion,
            qualityPolicyVersion: evidence.qualityPolicyVersion,
            evaluatorVersion: evidence.evaluatorVersion,
            controllerPolicyVersion: evidence.controllerPolicyVersion,
            profileVersion: profile.profileVersion,
            profileFingerprint: profile.fingerprint,
            loudnessLowerLUFS: loudness.bounds.lower,
            loudnessUpperLUFS: loudness.bounds.upper,
            loudnessMidpointLUFS: midpoint(loudness.bounds),
            truePeakLowerDBTP: truePeak.bounds.lower,
            truePeakUpperDBTP: truePeak.bounds.upper,
            truePeakMidpointDBTP: midpoint(truePeak.bounds)
        )
        return target.isStructurallyValid(sourceEvidence: evidence)
            ? target
            : nil
    }

    private static func currentArtifactsAreExact(
        _ artifacts: ProfessionalQualityPrimaryArtifacts
    ) -> Bool {
        let profile = artifacts.profile
        return profile.isComplete && profile.usesDiverseCalibration &&
            profile.schemaVersion ==
                ProfessionalQualityCalibrationProfile.schemaVersion &&
            profile.profileVersion ==
                ProfessionalQualityCalibrationProfile.profileVersion &&
            profile.observationVersion ==
                ProfessionalQualityObservation.observationVersion &&
            profile.evidenceVersion ==
                ProfessionalEvidenceReportBank.evidenceVersion &&
            profile.engineVersion == QualityQualificationContract.engineVersion &&
            profile.sampleRates ==
                ProfessionalQualityCalibrationProfile.requiredSampleRates &&
            profile.fingerprint ==
                ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint &&
            artifacts.evaluator.profile.fingerprint == profile.fingerprint &&
            artifacts.evaluator.policyVersion == expectedQualityPolicyVersion &&
            artifacts.evaluator.evaluatorVersion ==
                ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier
    }

    private static func samplesAreFinite(
        _ samples: [Float],
        cancellationRequested: @Sendable () -> Bool
    ) -> Bool {
        for (index, sample) in samples.enumerated() {
            if index.isMultiple(of: 4_096), cancellationRequested() {
                return false
            }
            guard sample.isFinite else { return false }
        }
        return !cancellationRequested()
    }

    private static func strictestBounds(
        metric: ProfessionalQualityMetric,
        checkpoints: [CanonicalJourneyCheckpoint],
        profile: ProfessionalQualityCalibrationProfile
    ) -> (
        checkpoint: CanonicalJourneyCheckpoint,
        bounds: ProfessionalQualityMetricBounds
    )? {
        checkpoints.compactMap { checkpoint in
            profile[checkpoint]?[metric].map { (checkpoint, $0) }
        }.min { $0.1.upper < $1.1.upper }
    }

    private static func midpoint(
        _ bounds: ProfessionalQualityMetricBounds
    ) -> Double {
        (bounds.lower + bounds.upper) / 2
    }
}
