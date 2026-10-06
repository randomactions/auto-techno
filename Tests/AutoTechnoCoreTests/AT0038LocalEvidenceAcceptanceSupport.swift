import AutoTechnoCore
import AutoTechnoDSP
import Foundation

/// Test-owned reconstruction of the existing descriptive projections. A witness
/// proves these bounded fields only; it is not item admission or perceptual quality.
struct AT0038LocalEvidenceWitness: Equatable {
    let kick: ProfessionalQualityKickFoundationLocalEvidence
    let masking: ProfessionalQualityMaskingLocalEvidence
}

enum AT0038AcceptanceError: Error, Equatable {
    case invalidProjection
    case incompleteNativeBank
}

enum AT0038LocalEvidenceAcceptanceSupport {
    /// Only original typed products enter here. Diagnostic trajectory JSON has
    /// no reconstruction path and cannot replace this source.
    static func reconstruct(_ bank: ProfessionalEvidenceReportBank) throws
        -> [AT0038LocalEvidenceWitness] {
        let checkpoints = CanonicalJourneyCheckpoint.allCases
        let rates = ProfessionalQualityCalibrationProfile.requiredSampleRates
        guard bank.engineVersion == QualityQualificationContract.engineVersion,
              bank.evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion,
              bank.sourceReportCount == checkpoints.count * rates.count,
              bank.reports.count == bank.sourceReportCount,
              bank.sampleRates == rates else {
            throw AT0038AcceptanceError.incompleteNativeBank
        }
        var identities = Set<String>()
        let kick = try bank.kickFoundationLocalFeatureReports()
        let masking = try bank.maskingLocalFeatureReports()
        guard kick.count == bank.reports.count, masking.count == kick.count else {
            throw AT0038AcceptanceError.incompleteNativeBank
        }
        var witnesses: [AT0038LocalEvidenceWitness] = []
        for (index, source) in bank.reports.enumerated() {
            let identity = source.checkpoint.rawValue + ":" + String(source.sampleRate)
            guard source.engineVersion == bank.engineVersion,
                  source.policyVersion == bank.policyVersion,
                  source.evidenceScope == CanonicalJourneyQualificationReport.currentEvidenceScope,
                  rates.contains(source.sampleRate), checkpoints.contains(source.checkpoint),
                  identities.insert(identity).inserted else {
                throw AT0038AcceptanceError.incompleteNativeBank
            }
            witnesses.append(try validate(candidate: source.selectedCandidateEvidence,
                checkpoint: source.checkpoint, engineVersion: source.engineVersion,
                policyVersion: source.policyVersion,
                sourceReportFingerprint: source.evidenceFingerprint,
                kick: kick[index], masking: masking[index]))
        }
        return witnesses
    }

    /// Independent source equations and field-by-field geometry checks, rather
    /// than trusting a passed label, reduced mean or a serialized local report.
    static func validate(candidate: AutonomousCandidateEvaluationVector,
                         checkpoint: CanonicalJourneyCheckpoint,
                         engineVersion: String, policyVersion: String,
                         sourceReportFingerprint: String,
                         kick: ProfessionalQualityKickFoundationLocalEvidence,
                         masking: ProfessionalQualityMaskingLocalEvidence) throws
        -> AT0038LocalEvidenceWitness {
        guard let phraseKind = AutonomousPhraseKind(rawValue: candidate.symbolic.phraseKind) else {
            throw AT0038AcceptanceError.invalidProjection
        }
        let primary = CanonicalJourneyCheckpoint.primaryQualification(
            phraseIndex: candidate.symbolic.phraseIndex, phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged) ?? .longContinuation
        let applicable = CanonicalJourneyCheckpoint.applicable(
            phraseIndex: candidate.symbolic.phraseIndex, phraseKind: phraseKind,
            chapterChanged: candidate.symbolic.chapterChanged)
        guard applicable.contains(checkpoint) || checkpoint == primary,
              candidate.isComplete, candidate.isFinite,
              candidate.stems.map(\.bar) == candidate.fullMix.bars.map(\.bar),
              candidate.masking.map(\.bar) == candidate.fullMix.bars.map(\.bar),
              engineVersion == QualityQualificationContract.engineVersion,
              !policyVersion.isEmpty, !sourceReportFingerprint.isEmpty,
              kick.schemaVersion == ProfessionalQualityKickFoundationLocalEvidence.schemaVersion,
              kick.evidenceVersion == ProfessionalQualityKickFoundationLocalEvidence.evidenceVersion,
              masking.schemaVersion == ProfessionalQualityMaskingLocalEvidence.schemaVersion,
              masking.evidenceVersion == ProfessionalQualityMaskingLocalEvidence.evidenceVersion,
              kick.engineVersion == engineVersion, masking.engineVersion == engineVersion,
              kick.policyVersion == policyVersion, masking.policyVersion == policyVersion,
              kick.sourceReportFingerprint == sourceReportFingerprint,
              masking.sourceReportFingerprint == sourceReportFingerprint,
              kick.planFingerprint == candidate.planFingerprint,
              masking.planFingerprint == candidate.planFingerprint,
              kick.checkpoint == checkpoint, masking.checkpoint == checkpoint,
              kick.sampleRate == candidate.routeContinuation.sampleRate,
              masking.sampleRate == candidate.routeContinuation.sampleRate,
              kick.sourceBarCount == candidate.sourceStemBarCount,
              kick.sourceBarCount == candidate.stems.count,
              masking.sourceBarCount == candidate.sourceMaskingBarCount,
              masking.sourceBarCount == candidate.masking.count else {
            throw AT0038AcceptanceError.invalidProjection
        }
        let pairs = candidate.stems.compactMap { stem -> (bar: Int, value: Double)? in
            guard let kick = stem.roles.first(where: { $0.role == MixRole.kick.rawValue }),
                  let foundation = stem.roles.first(where: { $0.role == MixRole.foundation.rawValue }),
                  kick.activeRMS > 0, foundation.activeRMS > 0 else { return nil }
            return (stem.bar, min(120, max(-120,
                20 * (log10(kick.activeRMS) - log10(foundation.activeRMS)))))
        }
        let values = pairs.map(\.value)
        let minimum = values.min(), maximum = values.max()
        let mean = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        let spread: Double? = minimum.flatMap { low in maximum.map { $0 - low } }
        guard kick.pairedBarCount == pairs.count,
              kick.barMeasurements.map(\.bar) == pairs.map(\.bar),
              kick.barMeasurements.map(\.kickOverFoundationDB) == values,
              kick.availability == (pairs.isEmpty ? .noActivePairedBars : .available),
              kick.meanDB == mean, kick.minimumDB == minimum,
              kick.maximumDB == maximum, kick.spreadDB == spread else {
            throw AT0038AcceptanceError.invalidProjection
        }
        let expected = candidate.masking.flatMap { bar in
            bar.observations.map { (bar.bar, $0) }
        }
        guard masking.observationCount == expected.count,
              masking.observations.count == expected.count else {
            throw AT0038AcceptanceError.invalidProjection
        }
        for ((bar, original), projected) in zip(expected, masking.observations) {
            guard projected.bar == bar, projected.bandName == original.bandName,
                  projected.lowerHz == original.lowerHz, projected.upperHz == original.upperHz,
                  projected.firstRole == original.firstRole, projected.secondRole == original.secondRole,
                  projected.analyzedWindowCount == original.analyzedWindowCount,
                  projected.activePairWindowCount == original.activePairWindowCount,
                  projected.overlapWindowCount == original.overlapWindowCount,
                  projected.longestOverlapRun == original.longestOverlapRun,
                  projected.maximumOverlap == original.maximumOverlap else {
                throw AT0038AcceptanceError.invalidProjection
            }
        }
        return AT0038LocalEvidenceWitness(kick: kick, masking: masking)
    }
}
