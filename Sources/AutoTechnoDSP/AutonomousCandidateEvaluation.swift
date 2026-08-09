import AutoTechnoCore
import Foundation

/// The three score-owned candidates that may participate in one detached
/// preparation transaction. This is provenance, not another runtime selector.
package enum AutonomousCandidateSlot: String, Codable, CaseIterable, Sendable {
    case primary
    case alternate
    case fallback
}

/// At most one initial render per candidate and one bounded correction render
/// may be retained by an evaluation transaction.
package enum AutonomousCandidateAttemptKind: String, Codable, CaseIterable, Sendable {
    case initialRender
    case correctionRender
}

/// Describes the evaluator comparison without embedding shipping policy in the
/// signal-evidence layer.
package enum AutonomousCandidateComparison: String, Codable, CaseIterable, Sendable {
    case unavailable
    case primary
    case alternate
    case fallback
    case tie
}

package struct AutonomousSymbolicEvidence: Codable, Equatable, Sendable {
    package let planFingerprint: String
    package let phraseIndex: Int
    package let startBar: Int
    package let declaredBarCount: Int
    package let resolvedBarCount: Int
    package let phraseKind: String
    package let pulseClarity: Double
    package let intentionalSpace: Double
    package let responseClosure: Double
    package let structuralTimeliness: Double
    package let identityContinuity: Double
    package let weakPositionCoverage: Double
    package let trailingSideRelationship: Double
    package let overactivityPenalty: Double
    package let overdueDebtCount: Int
    package let interestScore: Double
    package let interestValid: Bool
    package let chapterChanged: Bool
    package let alternate: Bool
    package let conservative: Bool
    package let boundsValid: Bool

    package init(
        planFingerprint: String,
        phraseIndex: Int,
        startBar: Int,
        declaredBarCount: Int,
        resolvedBarCount: Int,
        phraseKind: String,
        pulseClarity: Double,
        intentionalSpace: Double,
        responseClosure: Double,
        structuralTimeliness: Double,
        identityContinuity: Double,
        weakPositionCoverage: Double,
        trailingSideRelationship: Double,
        overactivityPenalty: Double,
        overdueDebtCount: Int,
        interestScore: Double,
        interestValid: Bool,
        chapterChanged: Bool,
        alternate: Bool,
        conservative: Bool,
        boundsValid: Bool
    ) {
        self.planFingerprint = planFingerprint
        self.phraseIndex = phraseIndex
        self.startBar = startBar
        self.declaredBarCount = declaredBarCount
        self.resolvedBarCount = resolvedBarCount
        self.phraseKind = phraseKind
        self.pulseClarity = pulseClarity
        self.intentionalSpace = intentionalSpace
        self.responseClosure = responseClosure
        self.structuralTimeliness = structuralTimeliness
        self.identityContinuity = identityContinuity
        self.weakPositionCoverage = weakPositionCoverage
        self.trailingSideRelationship = trailingSideRelationship
        self.overactivityPenalty = overactivityPenalty
        self.overdueDebtCount = overdueDebtCount
        self.interestScore = interestScore
        self.interestValid = interestValid
        self.chapterChanged = chapterChanged
        self.alternate = alternate
        self.conservative = conservative
        self.boundsValid = boundsValid
    }

    package var isFinite: Bool {
        [
            pulseClarity, intentionalSpace, responseClosure, structuralTimeliness,
            identityContinuity, weakPositionCoverage, trailingSideRelationship,
            overactivityPenalty, interestScore,
        ].allSatisfy { $0.isFinite }
    }

    package var isComplete: Bool {
        let derivedInterest = PhraseInterestReport(
            pulseClarity: pulseClarity,
            intentionalSpace: intentionalSpace,
            responseClosure: responseClosure,
            structuralTimeliness: structuralTimeliness,
            identityContinuity: identityContinuity,
            weakPositionCoverage: weakPositionCoverage,
            trailingSideRelationship: trailingSideRelationship,
            overactivityPenalty: overactivityPenalty,
            overdueDebtCount: overdueDebtCount
        )
        let interestIsCanonical =
            derivedInterest.pulseClarity == pulseClarity &&
            derivedInterest.intentionalSpace == intentionalSpace &&
            derivedInterest.responseClosure == responseClosure &&
            derivedInterest.structuralTimeliness == structuralTimeliness &&
            derivedInterest.identityContinuity == identityContinuity &&
            derivedInterest.weakPositionCoverage == weakPositionCoverage &&
            derivedInterest.trailingSideRelationship == trailingSideRelationship &&
            derivedInterest.overactivityPenalty == overactivityPenalty &&
            derivedInterest.overdueDebtCount == overdueDebtCount &&
            derivedInterest.score == interestScore &&
            derivedInterest.valid == interestValid
        return !planFingerprint.isEmpty && phraseIndex >= 0 && startBar >= 0 &&
            (1...AutonomousCandidateEvaluationVector.maximumBarCount).contains(declaredBarCount) &&
            resolvedBarCount == declaredBarCount &&
            AutonomousPhraseKind(rawValue: phraseKind) != nil && boundsValid
            && overdueDebtCount >= 0 && interestIsCanonical
    }
}

package struct AutonomousHardGateEvidence: Codable, Equatable, Sendable {
    package let symbolicValid: Bool
    package let graphValid: Bool
    package let audioSafetyValid: Bool
    package let fullMixFinite: Bool
    package let upperTimbreFinite: Bool
    package let blocksPresent: Bool
    package let blockChannelsAligned: Bool
    package let allSamplesFinite: Bool
    package let completeInputs: Bool

    package init(
        symbolicValid: Bool,
        graphValid: Bool,
        audioSafetyValid: Bool,
        fullMixFinite: Bool,
        upperTimbreFinite: Bool,
        blocksPresent: Bool,
        blockChannelsAligned: Bool,
        allSamplesFinite: Bool,
        completeInputs: Bool
    ) {
        self.symbolicValid = symbolicValid
        self.graphValid = graphValid
        self.audioSafetyValid = audioSafetyValid
        self.fullMixFinite = fullMixFinite
        self.upperTimbreFinite = upperTimbreFinite
        self.blocksPresent = blocksPresent
        self.blockChannelsAligned = blockChannelsAligned
        self.allSamplesFinite = allSamplesFinite
        self.completeInputs = completeInputs
    }

    package var passed: Bool {
        symbolicValid && graphValid && audioSafetyValid && fullMixFinite &&
            upperTimbreFinite && blocksPresent && blockChannelsAligned &&
            allSamplesFinite && completeInputs
    }

    package var isComplete: Bool { completeInputs }
}

package struct AutonomousBarFullMixEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let loudness: Double
    package let spectralCentroid: Double
    package let transientDensity: Double
    package let crestFactor: Double
    package let finite: Bool

    package init(
        bar: Int,
        loudness: Double,
        spectralCentroid: Double,
        transientDensity: Double,
        crestFactor: Double,
        finite: Bool
    ) {
        self.bar = bar
        self.loudness = loudness
        self.spectralCentroid = spectralCentroid
        self.transientDensity = transientDensity
        self.crestFactor = crestFactor
        self.finite = finite
    }

    package var isFinite: Bool {
        loudness.isFinite && spectralCentroid.isFinite &&
            transientDensity.isFinite && crestFactor.isFinite && finite &&
            (-200...0).contains(loudness) &&
            (0...(QualityQualificationContract.maximumSupportedSampleRate / 2))
                .contains(spectralCentroid) &&
            (0...30).contains(transientDensity) &&
            (0...1_024).contains(crestFactor)
    }
}

package final class AutonomousFullMixEvidence: Codable, Equatable, Sendable {
    package static let maximumAnalysisPeakWorkingByteCount = 6 * 1_024 * 1_024
    package let loudnessStandard: String
    package let truePeakStandard: String
    package let sourceBarCount: Int
    package let sourceEvidenceBarCount: Int
    package let analyzedFrameCount: Int
    package let sampleHash: String
    package let peak: Double
    package let truePeakEstimate: Double
    package let truePeakDBTP: Double
    package let rms: Double
    /// Compatibility wire field. It is identical to `integratedLoudness` in
    /// Professional Evidence v3 and no longer represents an RMS estimate.
    package let loudnessEstimate: Double
    package let integratedLoudness: Double
    package let maximumMomentaryLoudness: Double
    package let maximumShortTermLoudness: Double
    package let loudnessRange: Double
    package let momentaryBlockCount: Int
    package let absoluteGatedBlockCount: Int
    package let relativeGatedBlockCount: Int
    package let shortTermBlockCount: Int
    package let dcOffset: Double
    package let stereoCorrelation: Double
    package let lowStereoCorrelation: Double
    package let maximumBoundaryDelta: Double
    package let movementScore: Double
    package let analysisPeakWorkingByteCount: Int
    package let perceptual: StreamingPerceptualEvidence
    package let bars: [AutonomousBarFullMixEvidence]

    package init(
        sourceBarCount: Int,
        analyzedFrameCount: Int,
        sampleHash: String,
        peak: Double,
        truePeakEstimate: Double,
        rms: Double,
        loudnessEstimate: Double,
        maximumMomentaryLoudness: Double,
        maximumShortTermLoudness: Double,
        loudnessRange: Double,
        momentaryBlockCount: Int,
        absoluteGatedBlockCount: Int,
        relativeGatedBlockCount: Int,
        shortTermBlockCount: Int,
        dcOffset: Double,
        stereoCorrelation: Double,
        lowStereoCorrelation: Double,
        maximumBoundaryDelta: Double,
        movementScore: Double,
        analysisPeakWorkingByteCount: Int,
        perceptual: StreamingPerceptualEvidence,
        bars: [AutonomousBarFullMixEvidence]
    ) {
        loudnessStandard = BS1770LoudnessMeasurement.standard
        truePeakStandard = BS1770AudioEvidence.truePeakStandard
        self.sourceBarCount = sourceBarCount
        self.analyzedFrameCount = analyzedFrameCount
        self.sampleHash = sampleHash
        self.peak = peak
        self.truePeakEstimate = truePeakEstimate
        truePeakDBTP = BS1770AudioEvidence.decibelsTruePeak(
            amplitude: truePeakEstimate
        )
        self.rms = rms
        self.loudnessEstimate = loudnessEstimate
        integratedLoudness = loudnessEstimate
        self.maximumMomentaryLoudness = maximumMomentaryLoudness
        self.maximumShortTermLoudness = maximumShortTermLoudness
        self.loudnessRange = loudnessRange
        self.momentaryBlockCount = momentaryBlockCount
        self.absoluteGatedBlockCount = absoluteGatedBlockCount
        self.relativeGatedBlockCount = relativeGatedBlockCount
        self.shortTermBlockCount = shortTermBlockCount
        self.dcOffset = dcOffset
        self.stereoCorrelation = stereoCorrelation
        self.lowStereoCorrelation = lowStereoCorrelation
        self.maximumBoundaryDelta = maximumBoundaryDelta
        self.movementScore = movementScore
        self.analysisPeakWorkingByteCount = analysisPeakWorkingByteCount
        self.perceptual = perceptual
        sourceEvidenceBarCount = bars.count
        self.bars = Array(
            bars.prefix(AutonomousCandidateEvaluationVector.maximumBarCount)
        )
    }

    package static func == (
        lhs: AutonomousFullMixEvidence,
        rhs: AutonomousFullMixEvidence
    ) -> Bool {
        lhs.loudnessStandard == rhs.loudnessStandard &&
            lhs.truePeakStandard == rhs.truePeakStandard &&
            lhs.sourceBarCount == rhs.sourceBarCount &&
            lhs.sourceEvidenceBarCount == rhs.sourceEvidenceBarCount &&
            lhs.analyzedFrameCount == rhs.analyzedFrameCount &&
            lhs.sampleHash == rhs.sampleHash &&
            lhs.peak == rhs.peak &&
            lhs.truePeakEstimate == rhs.truePeakEstimate &&
            lhs.truePeakDBTP == rhs.truePeakDBTP &&
            lhs.rms == rhs.rms &&
            lhs.loudnessEstimate == rhs.loudnessEstimate &&
            lhs.integratedLoudness == rhs.integratedLoudness &&
            lhs.maximumMomentaryLoudness == rhs.maximumMomentaryLoudness &&
            lhs.maximumShortTermLoudness == rhs.maximumShortTermLoudness &&
            lhs.loudnessRange == rhs.loudnessRange &&
            lhs.momentaryBlockCount == rhs.momentaryBlockCount &&
            lhs.absoluteGatedBlockCount == rhs.absoluteGatedBlockCount &&
            lhs.relativeGatedBlockCount == rhs.relativeGatedBlockCount &&
            lhs.shortTermBlockCount == rhs.shortTermBlockCount &&
            lhs.dcOffset == rhs.dcOffset &&
            lhs.stereoCorrelation == rhs.stereoCorrelation &&
            lhs.lowStereoCorrelation == rhs.lowStereoCorrelation &&
            lhs.maximumBoundaryDelta == rhs.maximumBoundaryDelta &&
            lhs.movementScore == rhs.movementScore &&
            lhs.analysisPeakWorkingByteCount ==
                rhs.analysisPeakWorkingByteCount &&
            lhs.perceptual == rhs.perceptual && lhs.bars == rhs.bars
    }

    package var isFinite: Bool {
        [
            peak, truePeakEstimate, truePeakDBTP, rms, loudnessEstimate,
            integratedLoudness, maximumMomentaryLoudness,
            maximumShortTermLoudness, loudnessRange, dcOffset,
            stereoCorrelation, lowStereoCorrelation, maximumBoundaryDelta,
            movementScore,
        ].allSatisfy { $0.isFinite } && perceptual.finite &&
            bars.allSatisfy { $0.isFinite }
    }

    package var isComplete: Bool {
        let loudnessValues = bars.map { $0.loudness }
        let spectralValues = bars.map { $0.spectralCentroid }
        let transientValues = bars.map { $0.transientDensity }
        let crestValues = bars.map { $0.crestFactor }
        let derivedMovementScore =
            min(1, ((loudnessValues.max() ?? -120) -
                (loudnessValues.min() ?? -120)) / 8) * 0.34 +
            min(1, ((spectralValues.max() ?? 0) -
                (spectralValues.min() ?? 0)) / 800) * 0.24 +
            min(1, ((transientValues.max() ?? 0) -
                (transientValues.min() ?? 0)) / 2.5) * 0.22 +
            min(1, ((crestValues.max() ?? 0) -
                (crestValues.min() ?? 0)) / 3) * 0.20
        let movementIsCanonical = !movementScore.isFinite ||
            abs(movementScore - derivedMovementScore) <= 1e-12
        let expectedTruePeakDBTP = BS1770AudioEvidence.decibelsTruePeak(
            amplitude: truePeakEstimate
        )
        return loudnessStandard == BS1770LoudnessMeasurement.standard &&
            truePeakStandard == BS1770AudioEvidence.truePeakStandard &&
            !sampleHash.isEmpty && analyzedFrameCount >= sourceBarCount &&
            (1...AutonomousCandidateEvaluationVector.maximumBarCount).contains(sourceBarCount) &&
            sourceEvidenceBarCount == bars.count && bars.count == sourceBarCount &&
            Set(bars.map { $0.bar }).count == bars.count &&
            momentaryBlockCount >= 0 && absoluteGatedBlockCount >= 0 &&
            relativeGatedBlockCount >= 0 && shortTermBlockCount >= 0 &&
            absoluteGatedBlockCount <= momentaryBlockCount &&
            relativeGatedBlockCount <= absoluteGatedBlockCount &&
            abs(loudnessEstimate - integratedLoudness) <= 1e-9 &&
            abs(truePeakDBTP - expectedTruePeakDBTP) <= 1e-9 &&
            perceptual.isComplete &&
            perceptual.sourceFrameCount == analyzedFrameCount &&
            analysisPeakWorkingByteCount >= perceptual.peakWorkingByteCount &&
            (1...Self.maximumAnalysisPeakWorkingByteCount)
                .contains(analysisPeakWorkingByteCount) &&
            movementIsCanonical
    }

    package var signalSafetyValid: Bool {
        return isFinite && !bars.isEmpty && bars.allSatisfy { $0.finite } &&
            peak >= 0 && peak <= 0.95 && truePeakEstimate >= peak &&
            truePeakEstimate <= 0.95 && rms >= 0 && rms <= peak &&
            (-120...24).contains(integratedLoudness) &&
            (-120...24).contains(maximumMomentaryLoudness) &&
            (-120...24).contains(maximumShortTermLoudness) &&
            (0...120).contains(loudnessRange) &&
            abs(dcOffset) <= rms + 1e-6 &&
            (-1...1).contains(stereoCorrelation) &&
            (-1...1).contains(lowStereoCorrelation) &&
            (0...1).contains(movementScore) && abs(dcOffset) < 0.05 &&
            lowStereoCorrelation > 0.94 && maximumBoundaryDelta >= 0 &&
            maximumBoundaryDelta <= peak * 2 + 1e-12 &&
            maximumBoundaryDelta < 0.65
    }
}

package struct AutonomousMaskingObservationEvidence: Codable, Equatable, Sendable {
    package let bandName: String
    package let lowerHz: Double
    package let upperHz: Double
    package let firstRole: String
    package let secondRole: String
    package let analyzedWindowCount: Int
    package let activePairWindowCount: Int
    package let overlapWindowCount: Int
    package let longestOverlapRun: Int
    package let maximumOverlap: Double

    package init(
        bandName: String,
        lowerHz: Double,
        upperHz: Double,
        firstRole: String,
        secondRole: String,
        analyzedWindowCount: Int,
        activePairWindowCount: Int,
        overlapWindowCount: Int,
        longestOverlapRun: Int,
        maximumOverlap: Double
    ) {
        self.bandName = bandName
        self.lowerHz = lowerHz
        self.upperHz = upperHz
        self.firstRole = firstRole
        self.secondRole = secondRole
        self.analyzedWindowCount = analyzedWindowCount
        self.activePairWindowCount = activePairWindowCount
        self.overlapWindowCount = overlapWindowCount
        self.longestOverlapRun = longestOverlapRun
        self.maximumOverlap = maximumOverlap
    }

    package var isFinite: Bool {
        lowerHz.isFinite && upperHz.isFinite && maximumOverlap.isFinite
    }

    package var isComplete: Bool {
        let bandMatches = SpectrumMaskingAnalyzer.bands.contains {
            $0.name == bandName && $0.lowerHz == lowerHz && $0.upperHz == upperHz
        }
        let pairMatches = SpectrumMaskingAnalyzer.rolePairs.contains {
            $0.0.rawValue == firstRole && $0.1.rawValue == secondRole
        }
        let overlapRelationshipIsValid: Bool
        if activePairWindowCount == 0 {
            overlapRelationshipIsValid = overlapWindowCount == 0 &&
                longestOverlapRun == 0 && maximumOverlap == 0
        } else if overlapWindowCount == 0 {
            overlapRelationshipIsValid = longestOverlapRun == 0 &&
                maximumOverlap <= SpectrumMaskingAnalyzer.overlapThreshold
        } else {
            overlapRelationshipIsValid = longestOverlapRun >= 1 &&
                maximumOverlap > SpectrumMaskingAnalyzer.overlapThreshold
        }
        return bandMatches && pairMatches && overlapRelationshipIsValid &&
            analyzedWindowCount == SpectrumMaskingAnalyzer.analyzedWindowCount &&
            activePairWindowCount >= 0 && activePairWindowCount <= analyzedWindowCount &&
            overlapWindowCount >= 0 && overlapWindowCount <= activePairWindowCount &&
            longestOverlapRun >= 0 && longestOverlapRun <= overlapWindowCount &&
            (0...1).contains(maximumOverlap)
    }
}

package struct AutonomousMaskingBarEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let sourceObservationCount: Int
    package let observations: [AutonomousMaskingObservationEvidence]

    package init(
        bar: Int,
        sourceObservationCount: Int,
        observations: [AutonomousMaskingObservationEvidence]
    ) {
        self.bar = bar
        self.sourceObservationCount = sourceObservationCount
        self.observations = Array(
            observations.prefix(AutonomousCandidateEvaluationVector.maximumMaskingObservationsPerBar)
        )
    }

    package var isFinite: Bool { observations.allSatisfy { $0.isFinite } }

    package var isComplete: Bool {
        sourceObservationCount == AutonomousCandidateEvaluationVector.maximumMaskingObservationsPerBar &&
            observations.count == sourceObservationCount &&
            observations.allSatisfy { $0.isComplete } &&
            Set(observations.map {
                "\($0.firstRole)|\($0.secondRole)|\($0.bandName)"
            }).count == observations.count
    }
}

package struct AutonomousStemBandEvidence: Codable, Equatable, Sendable {
    package let band: String
    package let energy: Double

    package init(band: String, energy: Double) {
        self.band = band
        self.energy = energy
    }

    package var isFinite: Bool { energy.isFinite }
    package var isComplete: Bool {
        MixBand.allCases.map { $0.rawValue }.contains(band) && energy >= 0
    }
}

package struct AutonomousRoleStemEvidence: Codable, Equatable, Sendable {
    package let role: String
    package let rms: Double
    package let activeRMS: Double
    package let onsetRMS: Double
    package let peak: Double
    package let crestFactor: Double
    package let occupancy: Double
    package let sourceBandCount: Int
    package let bands: [AutonomousStemBandEvidence]

    package init(
        role: String,
        rms: Double,
        activeRMS: Double,
        onsetRMS: Double,
        peak: Double,
        crestFactor: Double,
        occupancy: Double,
        bands: [AutonomousStemBandEvidence]
    ) {
        self.role = role
        self.rms = rms
        self.activeRMS = activeRMS
        self.onsetRMS = onsetRMS
        self.peak = peak
        self.crestFactor = crestFactor
        self.occupancy = occupancy
        sourceBandCount = bands.count
        self.bands = Array(bands.prefix(MixBand.allCases.count))
    }

    package var isFinite: Bool {
        [rms, activeRMS, onsetRMS, peak, crestFactor, occupancy]
            .allSatisfy { $0.isFinite } && bands.allSatisfy { $0.isFinite }
    }

    package var isComplete: Bool {
        let maximumFloatMagnitude = Double(Float.greatestFiniteMagnitude)
        let expectedCrest = peak == 0 ? 0 : peak / max(rms, 0.000_000_001)
        let silentTupleIsConsistent = peak != 0 ||
            (rms == 0 && activeRMS == 0 && onsetRMS == 0 &&
                crestFactor == 0 && occupancy == 0 &&
                bands.allSatisfy { $0.energy == 0 })
        let activeTupleIsConsistent = peak == 0 ||
            (rms > 0 && activeRMS > 0 && occupancy > 0 &&
                bands.contains { $0.energy > 0 })
        return MixRole.allCases.map { $0.rawValue }.contains(role) &&
            rms >= 0 && rms <= peak && activeRMS >= rms && activeRMS <= peak &&
            onsetRMS >= 0 && onsetRMS <= peak && peak >= 0 &&
            peak <= maximumFloatMagnitude &&
            abs(crestFactor - expectedCrest) <= 1e-9 &&
            silentTupleIsConsistent && activeTupleIsConsistent &&
            (0...1).contains(occupancy) &&
            sourceBandCount == bands.count &&
            bands.count == MixBand.allCases.count &&
            bands.allSatisfy { $0.isComplete } &&
            bands.allSatisfy { $0.energy <= 4 * peak * peak + 1e-12 } &&
            Set(bands.map { $0.band }) == Set(MixBand.allCases.map { $0.rawValue })
    }
}

package struct AutonomousStemBarEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let sourceRoleCount: Int
    package let roles: [AutonomousRoleStemEvidence]

    package init(bar: Int, sourceRoleCount: Int, roles: [AutonomousRoleStemEvidence]) {
        self.bar = bar
        self.sourceRoleCount = sourceRoleCount
        self.roles = Array(
            roles.prefix(AutonomousCandidateEvaluationVector.maximumStemRolesPerBar)
        )
    }

    package var isFinite: Bool { roles.allSatisfy { $0.isFinite } }

    package var isComplete: Bool {
        sourceRoleCount == AutonomousCandidateEvaluationVector.maximumStemRolesPerBar &&
            roles.count == sourceRoleCount && roles.allSatisfy { $0.isComplete } &&
            Set(roles.map { $0.role }) == Set(MixRole.allCases.map { $0.rawValue })
    }
}

package struct AutonomousRoleGainEvidence: Codable, Equatable, Sendable {
    package let role: String
    package let gainDB: Double

    package init(role: String, gainDB: Double) {
        self.role = role
        self.gainDB = gainDB
    }

    package var isFinite: Bool { gainDB.isFinite }
    package var isComplete: Bool {
        guard let resolvedRole = MixRole(rawValue: role) else { return false }
        switch resolvedRole {
        case .kick:
            return (AutomaticMixBalancer.minimumKickCorrectionDB...0).contains(gainDB)
        case .foundation, .percussion, .upperTonal, .atmosphere:
            return gainDB == 0
        }
    }
}

package struct AutonomousAutomaticMixEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let section: String
    package let foundationCompanion: String
    package let sourceGainCount: Int
    package let gains: [AutonomousRoleGainEvidence]
    package let measuredKickOverFoundationDB: Double?
    package let targetKickOverFoundationDB: Double?

    package init(
        bar: Int,
        section: String,
        foundationCompanion: String,
        gains: [AutonomousRoleGainEvidence],
        measuredKickOverFoundationDB: Double?,
        targetKickOverFoundationDB: Double?
    ) {
        self.bar = bar
        self.section = section
        self.foundationCompanion = foundationCompanion
        sourceGainCount = gains.count
        self.gains = Array(gains.prefix(MixRole.allCases.count))
        self.measuredKickOverFoundationDB = measuredKickOverFoundationDB
        self.targetKickOverFoundationDB = targetKickOverFoundationDB
    }

    package var isFinite: Bool {
        gains.allSatisfy { $0.isFinite } &&
            (measuredKickOverFoundationDB?.isFinite ?? true) &&
            (targetKickOverFoundationDB?.isFinite ?? true)
    }

    package var isComplete: Bool {
        SectionKind(rawValue: section) != nil &&
            FoundationCompanion(rawValue: foundationCompanion) != nil &&
            sourceGainCount == gains.count && gains.count == MixRole.allCases.count &&
            gains.allSatisfy { $0.isComplete } &&
            Set(gains.map { $0.role }) == Set(MixRole.allCases.map { $0.rawValue }) &&
            (measuredKickOverFoundationDB == nil) == (targetKickOverFoundationDB == nil)
    }
}

/// One bounded record per rendered bar binds the score-owned kick syntax to the
/// exact detector and post-fader kick consequences from detached preparation.
/// It retains no PCM and does not participate in the shipping selector while
/// the professional-quality policy remains uncalibrated.
package struct AutonomousKickSyntaxBarEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let role: String
    package let scoreKickEventCount: Int
    package let scoreKickStepMask: UInt16
    package let renderedKickEventCount: Int
    package let renderedKickStepMask: UInt16
    package let renderedFrameCount: Int
    package let audibleGain: Double
    package let detectorPeak: Double
    package let detectorRMS: Double
    package let audiblePeak: Double
    package let audibleRMS: Double
    package let duckingEnvelopePeak: Double
    package let detectorSampleHash: String
    package let audibleSampleHash: String
    package let detectorNonzeroSampleCount: Int
    package let audibleNonzeroSampleCount: Int
    package let detectorToAudibleScaleMatches: Bool
    package let renderPassesMatch: Bool
    package let bindingValid: Bool

    package init(
        bar: Int,
        role: KickSyntaxRole,
        scoreKickEventCount: Int,
        scoreKickStepMask: UInt16,
        renderedKickEventCount: Int,
        renderedKickStepMask: UInt16,
        renderedFrameCount: Int,
        audibleGain: Double,
        detectorPeak: Double,
        detectorRMS: Double,
        audiblePeak: Double,
        audibleRMS: Double,
        duckingEnvelopePeak: Double,
        detectorSampleHash: String,
        audibleSampleHash: String,
        detectorNonzeroSampleCount: Int,
        audibleNonzeroSampleCount: Int,
        detectorToAudibleScaleMatches: Bool,
        renderPassesMatch: Bool,
        bindingValid: Bool
    ) {
        self.bar = bar
        self.role = role.rawValue
        self.scoreKickEventCount = scoreKickEventCount
        self.scoreKickStepMask = scoreKickStepMask
        self.renderedKickEventCount = renderedKickEventCount
        self.renderedKickStepMask = renderedKickStepMask
        self.renderedFrameCount = renderedFrameCount
        self.audibleGain = audibleGain
        self.detectorPeak = detectorPeak
        self.detectorRMS = detectorRMS
        self.audiblePeak = audiblePeak
        self.audibleRMS = audibleRMS
        self.duckingEnvelopePeak = duckingEnvelopePeak
        self.detectorSampleHash = detectorSampleHash
        self.audibleSampleHash = audibleSampleHash
        self.detectorNonzeroSampleCount = detectorNonzeroSampleCount
        self.audibleNonzeroSampleCount = audibleNonzeroSampleCount
        self.detectorToAudibleScaleMatches = detectorToAudibleScaleMatches
        self.renderPassesMatch = renderPassesMatch
        self.bindingValid = bindingValid
    }

    package var isFinite: Bool {
        [
            audibleGain, detectorPeak, detectorRMS, audiblePeak, audibleRMS,
            duckingEnvelopePeak,
        ].allSatisfy(\.isFinite)
    }

    @inline(never)
    package func isComplete(sampleRate: Double) -> Bool {
        let supportedRateRange = QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate
        guard let resolvedRole = KickSyntaxRole(rawValue: role),
              sampleRate.isFinite,
              supportedRateRange.contains(sampleRate),
              bar >= 0,
              renderedFrameCount == Self.barFrameCount(sampleRate: sampleRate),
              (0...16).contains(scoreKickEventCount),
              (0...16).contains(renderedKickEventCount),
              scoreKickStepMask.nonzeroBitCount == scoreKickEventCount,
              renderedKickStepMask.nonzeroBitCount == renderedKickEventCount,
              scoreKickEventCount == renderedKickEventCount,
              scoreKickStepMask == renderedKickStepMask,
              Self.isSampleHash(detectorSampleHash),
              Self.isSampleHash(audibleSampleHash),
              (0...renderedFrameCount).contains(detectorNonzeroSampleCount),
              (0...renderedFrameCount).contains(audibleNonzeroSampleCount),
              isFinite,
              (Self.minimumAudibleGain...KickMixBalance.audibleGain)
                .contains(audibleGain),
              detectorPeak >= 0,
              detectorPeak <= Double(Float.greatestFiniteMagnitude),
              detectorRMS >= 0,
              detectorRMS <= detectorPeak,
              audiblePeak >= 0,
              audiblePeak <= detectorPeak,
              audibleRMS >= 0,
              audibleRMS <= audiblePeak,
              audibleRMS <= detectorRMS,
              duckingEnvelopePeak >= 0,
              duckingEnvelopePeak <= detectorPeak,
              detectorNonzeroSampleCount == audibleNonzeroSampleCount,
              detectorToAudibleScaleMatches,
              renderPassesMatch,
              bindingValid else {
            return false
        }

        switch resolvedRole {
        case .grounded, .recovery:
            return scoreKickEventCount > 0 && scoreKickStepMask != 0 &&
                (scoreKickStepMask & 1) == 1 &&
                detectorNonzeroSampleCount > 0 && audibleNonzeroSampleCount > 0 &&
                detectorPeak > 0 && detectorRMS > 0 &&
                audiblePeak > 0 && audibleRMS > 0 && duckingEnvelopePeak > 0
        case .withheld:
            let expectedZeroHash = Self.zeroSampleHash(
                renderedFrameCount: renderedFrameCount
            )
            return scoreKickEventCount == 0 && scoreKickStepMask == 0 &&
                detectorNonzeroSampleCount == 0 && audibleNonzeroSampleCount == 0 &&
                detectorPeak.bitPattern == 0 && detectorRMS.bitPattern == 0 &&
                audiblePeak.bitPattern == 0 && audibleRMS.bitPattern == 0 &&
                duckingEnvelopePeak.bitPattern == 0 &&
                detectorSampleHash == expectedZeroHash &&
                audibleSampleHash == expectedZeroHash
        }
    }

    package static func zeroSampleHash(renderedFrameCount: Int) -> String {
        guard renderedFrameCount >= 0,
              renderedFrameCount <= Int.max / 4 else { return "" }
        var value: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        func mixing(_ input: UInt32, into hash: inout UInt64) {
            var bits = input
            for _ in 0..<4 {
                hash ^= UInt64(bits & 0xff)
                hash &*= prime
                bits >>= 8
            }
        }
        mixing(1, into: &value)
        mixing(0x9e37_79b9, into: &value)
        mixing(UInt32(truncatingIfNeeded: renderedFrameCount), into: &value)
        value &*= power(prime, exponent: renderedFrameCount * 4)
        return fixedWidthFingerprintHex(value)
    }

    private static var minimumAudibleGain: Double {
        let minimumAutomaticGain = Float(pow(
            10,
            AutomaticMixBalancer.minimumKickCorrectionDB / 20
        ))
        return KickMixBalance.audibleGain * Double(minimumAutomaticGain)
    }

    private static func barFrameCount(sampleRate: Double) -> Int {
        Int((240.0 / AutonomousSessionDirector.bpm * sampleRate).rounded())
    }

    private static func power(_ base: UInt64, exponent: Int) -> UInt64 {
        var base = base
        var exponent = exponent
        var result: UInt64 = 1
        while exponent > 0 {
            if exponent & 1 == 1 { result &*= base }
            base &*= base
            exponent >>= 1
        }
        return result
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Bounded, event-local evidence for the existing score-owned groove pulse.
/// The record contains only reduced signal observations from the exact dry
/// sample that was rendered into the percussion path; no PCM is retained.
package struct AutonomousGroovePulseEventEvidence: Codable, Equatable, Sendable {
    package static let maximumSourceRMS = 0.05
    package static let minimumTailToAttackDB = -120.0
    package static let maximumTailToAttackDB = 120.0

    package let step: Int
    package let intensity: Double
    package let strikeZone: String
    package let damping: Double
    package let timbreMicrovariation: Double
    package let renderedFrameCount: Int
    package let sampleHash: String
    package let sourceRMS: Double
    package let spectralCentroidHz: Double
    package let tailToAttackDB: Double
    package let finite: Bool

    package init(
        step: Int,
        intensity: Double,
        strikeZone: String,
        damping: Double,
        timbreMicrovariation: Double,
        renderedFrameCount: Int,
        sampleHash: String,
        sourceRMS: Double,
        spectralCentroidHz: Double,
        tailToAttackDB: Double,
        finite: Bool
    ) {
        self.step = step
        self.intensity = intensity
        self.strikeZone = strikeZone
        self.damping = damping
        self.timbreMicrovariation = timbreMicrovariation
        self.renderedFrameCount = renderedFrameCount
        self.sampleHash = sampleHash
        self.sourceRMS = sourceRMS
        self.spectralCentroidHz = spectralCentroidHz
        self.tailToAttackDB = tailToAttackDB
        self.finite = finite
    }

    package var isFinite: Bool {
        finite && [
            intensity, damping, timbreMicrovariation, sourceRMS,
            spectralCentroidHz, tailToAttackDB,
        ].allSatisfy { $0.isFinite }
    }

    package func isComplete(sampleRate: Double) -> Bool {
        sampleRate.isFinite &&
            (QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate)
                .contains(sampleRate) &&
            GroovePulseStrikeZone(rawValue: strikeZone) != nil &&
            (0..<16).contains(step) &&
            (0...1).contains(intensity) &&
            (0.25...0.75).contains(damping) &&
            (-0.04...0.04).contains(timbreMicrovariation) &&
            renderedFrameCount == Int(sampleRate * GroovePulseVoice.durationSeconds) &&
            Self.isSampleHash(sampleHash) &&
            (0...Self.maximumSourceRMS).contains(sourceRMS) &&
            (0...(sampleRate / 2)).contains(spectralCentroidHz) &&
            (Self.minimumTailToAttackDB...Self.maximumTailToAttackDB)
                .contains(tailToAttackDB)
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Explicit evidence for every rendered bar, including bars with no groove
/// pulses. Separate score and render-source counts prevent either side of the
/// one-to-one attribution from being silently truncated.
package struct AutonomousGroovePulseBarEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let sourceScoreEventCount: Int
    package let sourceRenderEventCount: Int
    package let events: [AutonomousGroovePulseEventEvidence]

    package init(
        bar: Int,
        sourceScoreEventCount: Int,
        sourceRenderEventCount: Int,
        events: [AutonomousGroovePulseEventEvidence]
    ) {
        self.bar = bar
        self.sourceScoreEventCount = sourceScoreEventCount
        self.sourceRenderEventCount = sourceRenderEventCount
        self.events = Array(
            events.prefix(AutonomousCandidateEvaluationVector.maximumGroovePulseEventsPerBar)
        )
    }

    package var isFinite: Bool { events.allSatisfy { $0.isFinite } }

    package func isComplete(sampleRate: Double) -> Bool {
        bar >= 0 && sourceScoreEventCount >= 0 &&
            sourceScoreEventCount <=
                AutonomousCandidateEvaluationVector.maximumGroovePulseEventsPerBar &&
            sourceRenderEventCount == sourceScoreEventCount &&
            events.count == sourceScoreEventCount &&
            events.map { $0.step } == events.map { $0.step }.sorted() &&
            Set(events.map { $0.step }).count == events.count &&
            events.allSatisfy { $0.isComplete(sampleRate: sampleRate) }
    }
}

/// Reduced signal evidence for one ordinary closed-hat score event. The
/// semantic decay role is replayable from the resolved ensemble; signal
/// observations come from the exact dry sample rendered in the same pass.
package struct AutonomousClosedHatEventEvidence: Codable, Equatable, Sendable {
    package static let maximumSourceRMS = 0.25
    package static let minimumTailToAttackDB = -120.0
    package static let maximumTailToAttackDB = 120.0

    package let scoreEventIndex: Int
    package let step: Int
    package let role: String
    package let intensity: Double
    package let timingOffsetInSteps: Double
    package let relocated: Bool
    package let decayRateScale: Double
    package let renderedFrameCount: Int
    package let sampleHash: String
    package let sourceRMS: Double
    package let spectralCentroidHz: Double
    package let tailToAttackDB: Double
    package let finite: Bool

    package init(
        scoreEventIndex: Int,
        step: Int,
        role: String,
        intensity: Double,
        timingOffsetInSteps: Double,
        relocated: Bool,
        decayRateScale: Double,
        renderedFrameCount: Int,
        sampleHash: String,
        sourceRMS: Double,
        spectralCentroidHz: Double,
        tailToAttackDB: Double,
        finite: Bool
    ) {
        self.scoreEventIndex = scoreEventIndex
        self.step = step
        self.role = role
        self.intensity = intensity
        self.timingOffsetInSteps = timingOffsetInSteps
        self.relocated = relocated
        self.decayRateScale = decayRateScale
        self.renderedFrameCount = renderedFrameCount
        self.sampleHash = sampleHash
        self.sourceRMS = sourceRMS
        self.spectralCentroidHz = spectralCentroidHz
        self.tailToAttackDB = tailToAttackDB
        self.finite = finite
    }

    package var isFinite: Bool {
        finite && [
            intensity, timingOffsetInSteps, decayRateScale, sourceRMS,
            spectralCentroidHz, tailToAttackDB,
        ].allSatisfy { $0.isFinite }
    }

    package func isComplete(sampleRate: Double) -> Bool {
        guard let resolvedRole = ClosedHatDecayRole(rawValue: role) else {
            return false
        }
        let expectedScale = switch resolvedRole {
        case .neutral: 1.0
        case .openHatCompanion:
            ClosedHatVoiceContract.openHatCompanionDecayRateScale
        }
        return sampleRate.isFinite &&
            (QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate)
                .contains(sampleRate) &&
            (0..<(16 * 6)).contains(scoreEventIndex) &&
            (0..<16).contains(step) &&
            (0...1).contains(intensity) &&
            (0...0.24).contains(timingOffsetInSteps) &&
            decayRateScale == expectedScale &&
            renderedFrameCount == ClosedHatVoiceContract.frameCount(
                sampleRate: sampleRate
            ) && Self.isSampleHash(sampleHash) &&
            (0...Self.maximumSourceRMS).contains(sourceRMS) &&
            (0...(sampleRate / 2)).contains(spectralCentroidHz) &&
            (Self.minimumTailToAttackDB...Self.maximumTailToAttackDB)
                .contains(tailToAttackDB)
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

package struct AutonomousInstrumentAssignmentEvidence: Codable, Equatable, Sendable {
    package let use: String
    package let architecture: String
    package let patch: String
    package let color: Double
    package let shape: Double
    package let motion: Double
    package let space: Double
    package let effects: [String]

    package init(_ assignment: InstrumentAssignment) {
        use = assignment.use.rawValue
        architecture = assignment.architecture.rawValue
        patch = assignment.patch.rawValue
        color = assignment.automation.color
        shape = assignment.automation.shape
        motion = assignment.automation.motion
        space = assignment.automation.space
        effects = assignment.effects.map { $0.rawValue }
    }

    package var isFinite: Bool {
        [color, shape, motion, space].allSatisfy { $0.isFinite }
    }

    package var isComplete: Bool {
        let requestedEffects = Set(effects)
        let canonicalEffects = InstrumentEffect.allCases
            .filter { requestedEffects.contains($0.rawValue) }
            .map { $0.rawValue }
        guard let use = InstrumentUse(rawValue: use),
              let architecture = InstrumentArchitecture(rawValue: architecture),
              let patch = InstrumentPatch(rawValue: patch),
              let capability = InstrumentPalette.capability(for: patch),
              patch.architecture == architecture,
              capability.supports(use),
              effects.count == requestedEffects.count,
              effects == canonicalEffects,
              Set(effects).isSubset(of: Set(capability.compatibleEffects.map { $0.rawValue })) else {
            return false
        }
        return [color, shape, motion, space].allSatisfy { (0...1).contains($0) } &&
            (use != .foundationBass || space == 0)
    }
}

package struct AutonomousInstrumentArchitectureEvidence: Codable, Equatable, Sendable {
    package let architecture: String
    package let sourceAssignmentCount: Int
    package let assignments: [AutonomousInstrumentAssignmentEvidence]
    package let eventCount: Int
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let finite: Bool

    package init(_ evidence: InstrumentArchitectureRenderEvidence) {
        architecture = evidence.architecture.rawValue
        sourceAssignmentCount = evidence.assignments.count
        assignments = Array(evidence.assignments.prefix(
            AutonomousCandidateEvaluationVector.maximumInstrumentAssignmentsPerArchitecture
        )).map(AutonomousInstrumentAssignmentEvidence.init)
        eventCount = evidence.eventCount
        sampleHash = evidence.sampleHash
        peak = Double(evidence.peak)
        rms = Double(evidence.rms)
        finite = evidence.finite
    }

    package var isFinite: Bool {
        finite && peak.isFinite && rms.isFinite &&
            assignments.allSatisfy { $0.isFinite }
    }

    package var isComplete: Bool {
        InstrumentArchitecture(rawValue: architecture) != nil &&
            sourceAssignmentCount == assignments.count &&
            !assignments.isEmpty &&
            assignments.count <=
                AutonomousCandidateEvaluationVector.maximumInstrumentAssignmentsPerArchitecture &&
            assignments.allSatisfy {
                $0.architecture == architecture && $0.isComplete
            } &&
            eventCount >= assignments.count &&
            eventCount <= AutonomousCandidateEvaluationVector.maximumInstrumentEventsPerBar &&
            Self.isSampleHash(sampleHash) &&
            peak >= 0 && rms >= 0 && rms <= peak &&
            peak <= Double(Float.greatestFiniteMagnitude)
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Explicit per-bar ownership keeps empty bars truthful and prevents either
/// the score or render side of the event bijection from being truncated away.
package struct AutonomousClosedHatBarEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let sourceScoreEventCount: Int
    package let sourceRenderEventCount: Int
    package let events: [AutonomousClosedHatEventEvidence]

    package init(
        bar: Int,
        sourceScoreEventCount: Int,
        sourceRenderEventCount: Int,
        events: [AutonomousClosedHatEventEvidence]
    ) {
        self.bar = bar
        self.sourceScoreEventCount = sourceScoreEventCount
        self.sourceRenderEventCount = sourceRenderEventCount
        self.events = Array(
            events.prefix(
                AutonomousCandidateEvaluationVector.maximumClosedHatEventsPerBar
            )
        )
    }

    package var isFinite: Bool { events.allSatisfy { $0.isFinite } }

    package func isComplete(sampleRate: Double) -> Bool {
        bar >= 0 && sourceScoreEventCount >= 0 &&
            sourceScoreEventCount <=
                AutonomousCandidateEvaluationVector.maximumClosedHatEventsPerBar &&
            sourceRenderEventCount == sourceScoreEventCount &&
            events.count == sourceScoreEventCount &&
            events.map { $0.scoreEventIndex } ==
                events.map { $0.scoreEventIndex }.sorted() &&
            Set(events.map { $0.scoreEventIndex }).count == events.count &&
            events.allSatisfy { $0.isComplete(sampleRate: sampleRate) }
    }
}

package struct AutonomousInstrumentBarEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let sourceArchitectureCount: Int
    package let architectures: [AutonomousInstrumentArchitectureEvidence]

    package init(bar: Int, evidence: [InstrumentArchitectureRenderEvidence]) {
        self.bar = bar
        sourceArchitectureCount = evidence.count
        architectures = Array(evidence.prefix(
            AutonomousCandidateEvaluationVector.maximumInstrumentArchitecturesPerBar
        )).map(AutonomousInstrumentArchitectureEvidence.init)
    }

    package var isFinite: Bool { architectures.allSatisfy { $0.isFinite } }

    package var isComplete: Bool {
        bar >= 0 && sourceArchitectureCount == architectures.count &&
            architectures.count <=
                AutonomousCandidateEvaluationVector.maximumInstrumentArchitecturesPerBar &&
            architectures.allSatisfy { $0.isComplete } &&
            architectures.map { $0.architecture } ==
                architectures.map { $0.architecture }.sorted {
                let lhs = InstrumentArchitecture(rawValue: $0).flatMap {
                    InstrumentArchitecture.allCases.firstIndex(of: $0)
                } ?? 0
                let rhs = InstrumentArchitecture(rawValue: $1).flatMap {
                    InstrumentArchitecture.allCases.firstIndex(of: $0)
                } ?? 0
                return lhs < rhs
            } && Set(architectures.map { $0.architecture }).count == architectures.count
    }
}

/// Fixed role-local PCM identity for one upper companion role. This remains a
/// compact consequence record: the transient dry tap never leaves detached
/// preparation and no per-event PCM or crest duplicate enters the candidate.
package struct AutonomousUpperTimingRoleSignalEvidence: Codable, Equatable, Sendable {
    package let role: String
    package let eventCount: Int
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let finite: Bool

    package init(
        role: SynthRole,
        eventCount: Int,
        sampleHash: String,
        peak: Double,
        rms: Double,
        finite: Bool
    ) {
        self.role = role.rawValue
        self.eventCount = eventCount
        self.sampleHash = sampleHash
        self.peak = peak
        self.rms = rms
        self.finite = finite
    }

    init(role: SynthRole, evidence: UpperTimingRoleSignalEvidence) {
        self.init(
            role: role,
            eventCount: evidence.eventCount,
            sampleHash: evidence.sampleHash,
            peak: Double(evidence.peak),
            rms: Double(evidence.rms),
            finite: evidence.finite
        )
    }

    package var isFinite: Bool {
        finite && peak.isFinite && rms.isFinite
    }

    package func isComplete(expectedRole: SynthRole, maximumEventCount: Int) -> Bool {
        role == expectedRole.rawValue && eventCount >= 0 &&
            eventCount <= maximumEventCount && Self.isSampleHash(sampleHash) &&
            peak >= 0 && peak <= Double(Float.greatestFiniteMagnitude) &&
            rms >= 0 && rms <= peak
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// One compact record per rendered bar binds the score-owned upper timing
/// offsets to exact applied onset frames and role-local dry consequences. The
/// bounded transient renderer tuples are reduced to fingerprints and counts;
/// they are never retained in the candidate transaction.
package struct AutonomousUpperTimingBarEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let chapter: String
    package let bpm: Double
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let sourceScoreNoteCount: Int
    package let sourceRenderEventCount: Int
    package let anchorEventCount: Int
    package let activeOffsetCount: Int
    package let protectedRoleActiveOffsetCount: Int
    package let minimumOffsetInSteps: Double
    package let maximumOffsetInSteps: Double
    package let maximumRoleSpreadInSteps: Double
    package let shadowMinimumOffsetInSteps: Double
    package let shadowMaximumOffsetInSteps: Double
    package let responseMinimumOffsetInSteps: Double
    package let responseMaximumOffsetInSteps: Double
    package let scoreFingerprint: String
    package let renderFingerprint: String
    package let appliedGateFingerprint: String
    package let shadowSignal: AutonomousUpperTimingRoleSignalEvidence
    package let responseSignal: AutonomousUpperTimingRoleSignalEvidence
    package let bindingValid: Bool
    package let finite: Bool

    package init(
        bar: Int,
        chapter: InterlockChapter,
        bpm: Double,
        sampleRate: Double,
        renderedFrameCount: Int,
        sourceScoreNoteCount: Int,
        sourceRenderEventCount: Int,
        anchorEventCount: Int,
        activeOffsetCount: Int,
        protectedRoleActiveOffsetCount: Int,
        minimumOffsetInSteps: Double,
        maximumOffsetInSteps: Double,
        maximumRoleSpreadInSteps: Double,
        shadowMinimumOffsetInSteps: Double,
        shadowMaximumOffsetInSteps: Double,
        responseMinimumOffsetInSteps: Double,
        responseMaximumOffsetInSteps: Double,
        scoreFingerprint: String,
        renderFingerprint: String,
        appliedGateFingerprint: String,
        shadowSignal: AutonomousUpperTimingRoleSignalEvidence,
        responseSignal: AutonomousUpperTimingRoleSignalEvidence,
        bindingValid: Bool,
        finite: Bool
    ) {
        self.bar = bar
        self.chapter = chapter.rawValue
        self.bpm = bpm
        self.sampleRate = sampleRate
        self.renderedFrameCount = renderedFrameCount
        self.sourceScoreNoteCount = sourceScoreNoteCount
        self.sourceRenderEventCount = sourceRenderEventCount
        self.anchorEventCount = anchorEventCount
        self.activeOffsetCount = activeOffsetCount
        self.protectedRoleActiveOffsetCount = protectedRoleActiveOffsetCount
        self.minimumOffsetInSteps = minimumOffsetInSteps
        self.maximumOffsetInSteps = maximumOffsetInSteps
        self.maximumRoleSpreadInSteps = maximumRoleSpreadInSteps
        self.shadowMinimumOffsetInSteps = shadowMinimumOffsetInSteps
        self.shadowMaximumOffsetInSteps = shadowMaximumOffsetInSteps
        self.responseMinimumOffsetInSteps = responseMinimumOffsetInSteps
        self.responseMaximumOffsetInSteps = responseMaximumOffsetInSteps
        self.scoreFingerprint = scoreFingerprint
        self.renderFingerprint = renderFingerprint
        self.appliedGateFingerprint = appliedGateFingerprint
        self.shadowSignal = shadowSignal
        self.responseSignal = responseSignal
        self.bindingValid = bindingValid
        self.finite = finite
    }

    package var isFinite: Bool {
        finite && [
            bpm, sampleRate, minimumOffsetInSteps, maximumOffsetInSteps,
            maximumRoleSpreadInSteps, shadowMinimumOffsetInSteps,
            shadowMaximumOffsetInSteps, responseMinimumOffsetInSteps,
            responseMaximumOffsetInSteps,
        ].allSatisfy(\.isFinite) && shadowSignal.isFinite && responseSignal.isFinite
    }

    package func normalTimingEligibility(
        phraseKind: AutonomousPhraseKind,
        conservative: Bool
    ) -> Bool {
        chapter == InterlockChapter.breath.rawValue &&
            SynthPerformancePlan.upperTimingAperture(absoluteBar: bar) > 0 &&
            anchorEventCount > 0 &&
            (shadowSignal.eventCount > 0 || responseSignal.eventCount > 0) &&
            !conservative && phraseKind != .identityReturn &&
            phraseKind != .majorBreak
    }

    package func isComplete(
        routeSampleRate: Double,
        phraseKind: AutonomousPhraseKind,
        conservative: Bool
    ) -> Bool {
        let maximumEvents = AutonomousCandidateEvaluationVector
            .maximumUpperTimingEventsPerBar
        let companionCountResult = shadowSignal.eventCount.addingReportingOverflow(
            responseSignal.eventCount
        )
        let totalCountResult = anchorEventCount.addingReportingOverflow(
            companionCountResult.partialValue
        )
        guard bar >= 0, InterlockChapter(rawValue: chapter) != nil,
              bpm == AutonomousSessionDirector.bpm,
              sampleRate == routeSampleRate,
              sampleRate >= QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <= QualityQualificationContract.maximumSupportedSampleRate,
              renderedFrameCount == Self.barFrames(bpm: bpm, sampleRate: sampleRate),
              sourceScoreNoteCount >= 0, sourceScoreNoteCount <= maximumEvents,
              sourceRenderEventCount == sourceScoreNoteCount,
              anchorEventCount >= 0, anchorEventCount <= sourceRenderEventCount,
              activeOffsetCount >= 0, activeOffsetCount <= sourceScoreNoteCount,
              protectedRoleActiveOffsetCount == 0,
              (0...ResolvedUpperNote.maximumTimingOffsetInSteps).contains(
                minimumOffsetInSteps
              ),
              (0...ResolvedUpperNote.maximumTimingOffsetInSteps).contains(
                maximumOffsetInSteps
              ),
              minimumOffsetInSteps <= maximumOffsetInSteps,
              maximumRoleSpreadInSteps ==
                maximumOffsetInSteps - minimumOffsetInSteps,
              (0...ResolvedUpperNote.maximumTimingOffsetInSteps).contains(
                maximumRoleSpreadInSteps
              ),
              (0...ResolvedUpperNote.maximumTimingOffsetInSteps).contains(
                shadowMinimumOffsetInSteps
              ),
              (0...ResolvedUpperNote.maximumTimingOffsetInSteps).contains(
                shadowMaximumOffsetInSteps
              ),
              shadowMinimumOffsetInSteps <= shadowMaximumOffsetInSteps,
              (0...ResolvedUpperNote.maximumTimingOffsetInSteps).contains(
                responseMinimumOffsetInSteps
              ),
              (0...ResolvedUpperNote.maximumTimingOffsetInSteps).contains(
                responseMaximumOffsetInSteps
              ),
              responseMinimumOffsetInSteps <= responseMaximumOffsetInSteps,
              Self.isFingerprint(scoreFingerprint),
              scoreFingerprint == renderFingerprint,
              Self.isFingerprint(appliedGateFingerprint),
              shadowSignal.isComplete(
                expectedRole: .shadow,
                maximumEventCount: sourceScoreNoteCount
              ),
              responseSignal.isComplete(
                expectedRole: .response,
                maximumEventCount: sourceScoreNoteCount
              ),
              !companionCountResult.overflow,
              !totalCountResult.overflow,
              totalCountResult.partialValue <= sourceRenderEventCount,
              bindingValid else {
            return false
        }
        let companionRoleSignalsAreAudible =
            (shadowSignal.eventCount == 0 ||
                (shadowSignal.peak > 0 && shadowSignal.rms > 0)) &&
            (responseSignal.eventCount == 0 ||
                (responseSignal.peak > 0 && responseSignal.rms > 0))
        guard companionRoleSignalsAreAudible else { return false }

        let isMacroEndpoint = bar.isMultiple(of: 16) ||
            ((bar % 16) + 16) % 16 == 15
        if activeOffsetCount == 0 || isMacroEndpoint {
            return activeOffsetCount == 0 &&
                minimumOffsetInSteps.bitPattern == 0 &&
                maximumOffsetInSteps.bitPattern == 0 &&
                maximumRoleSpreadInSteps.bitPattern == 0 &&
                shadowMinimumOffsetInSteps.bitPattern == 0 &&
                shadowMaximumOffsetInSteps.bitPattern == 0 &&
                responseMinimumOffsetInSteps.bitPattern == 0 &&
                responseMaximumOffsetInSteps.bitPattern == 0
        }

        guard chapter == InterlockChapter.breath.rawValue,
              !conservative,
              phraseKind != .identityReturn,
              phraseKind != .majorBreak,
              anchorEventCount > 0,
              companionCountResult.partialValue > 0,
              minimumOffsetInSteps.bitPattern == 0,
              activeOffsetCount == companionCountResult.partialValue else {
            return false
        }
        let fullDepth = ResolvedUpperNote.maximumTimingOffsetInSteps *
            SynthPerformancePlan.upperTimingAperture(absoluteBar: bar)
        let expectedMaximum = responseSignal.eventCount > 0
            ? fullDepth : fullDepth * 0.5
        let expectedShadowOffset = shadowSignal.eventCount > 0
            ? fullDepth * 0.5 : 0
        let expectedResponseOffset = responseSignal.eventCount > 0
            ? fullDepth : 0
        return expectedMaximum > 0 &&
            maximumOffsetInSteps == expectedMaximum &&
            maximumRoleSpreadInSteps == expectedMaximum &&
            shadowMinimumOffsetInSteps == expectedShadowOffset &&
            shadowMaximumOffsetInSteps == expectedShadowOffset &&
            responseMinimumOffsetInSteps == expectedResponseOffset &&
            responseMaximumOffsetInSteps == expectedResponseOffset
    }

    private static func barFrames(bpm: Double, sampleRate: Double) -> Int {
        max(1, Int((240.0 / bpm * sampleRate).rounded()))
    }

    private static func isFingerprint(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Bounded same-pass evidence for the existing shared pulse-echo return. The
/// instrument vector already owns patch, use, automation, and effect access;
/// this record retains only the exact delay/drive geometry and its PCM
/// consequence so shared-return evidence is not misattributed to one voice.
package struct AutonomousPulseEchoDriveBarEvidence: Codable, Equatable, Sendable {
    package static let maximumAppliedAmount =
        PulseEchoTextureArticulation.maximumAppliedAmount
    package static let metricTolerance = 0.000_001

    package let bar: Int
    package let bpm: Double
    package let delayFrameCount: Int
    package let scoreEnabled: Bool
    package let earliestPulseEchoOnsetStep: Int?
    package let driveEligible: Bool
    package let machineTexture: Double
    package let appliedAmount: Double
    package let transitionFrameCount: Int
    package let renderedFrameCount: Int
    package let currentSendRMS: Double
    package let preDriveSampleHash: String
    package let postDriveSampleHash: String
    package let firstPreDriveSampleBitPattern: UInt32
    package let firstPostDriveSampleBitPattern: UInt32
    package let lastPreDriveSampleBitPattern: UInt32
    package let lastPostDriveSampleBitPattern: UInt32
    package let changedFrameIndex: Int
    package let changedPreDriveSampleBitPattern: UInt32
    package let preDrivePeak: Double
    package let preDrivePeakFrameIndex: Int
    package let postDrivePeak: Double
    package let postDrivePeakFrameIndex: Int
    package let postDrivePeakPreDriveSample: Double
    package let postDrivePeakEffectiveAmount: Double
    package let preDriveRMS: Double
    package let postDriveRMS: Double
    package let preDriveLowBandRMS: Double
    package let postDriveLowBandRMS: Double
    package let differenceRMS: Double
    package let interlockChapter: String
    package let bindingValid: Bool
    package let finite: Bool

    package init(
        bar: Int,
        bpm: Double,
        delayFrameCount: Int,
        scoreEnabled: Bool,
        earliestPulseEchoOnsetStep: Int?,
        driveEligible: Bool,
        machineTexture: Double,
        appliedAmount: Double,
        transitionFrameCount: Int,
        renderedFrameCount: Int,
        currentSendRMS: Double,
        preDriveSampleHash: String,
        postDriveSampleHash: String,
        firstPreDriveSampleBitPattern: UInt32,
        firstPostDriveSampleBitPattern: UInt32,
        lastPreDriveSampleBitPattern: UInt32,
        lastPostDriveSampleBitPattern: UInt32,
        changedFrameIndex: Int,
        changedPreDriveSampleBitPattern: UInt32,
        preDrivePeak: Double,
        preDrivePeakFrameIndex: Int,
        postDrivePeak: Double,
        postDrivePeakFrameIndex: Int,
        postDrivePeakPreDriveSample: Double,
        postDrivePeakEffectiveAmount: Double,
        preDriveRMS: Double,
        postDriveRMS: Double,
        preDriveLowBandRMS: Double,
        postDriveLowBandRMS: Double,
        differenceRMS: Double,
        interlockChapter: InterlockChapter,
        bindingValid: Bool = true,
        finite: Bool
    ) {
        self.bar = bar
        self.bpm = bpm
        self.delayFrameCount = delayFrameCount
        self.scoreEnabled = scoreEnabled
        self.earliestPulseEchoOnsetStep = earliestPulseEchoOnsetStep
        self.driveEligible = driveEligible
        self.machineTexture = machineTexture
        self.appliedAmount = appliedAmount
        self.transitionFrameCount = transitionFrameCount
        self.renderedFrameCount = renderedFrameCount
        self.currentSendRMS = currentSendRMS
        self.preDriveSampleHash = preDriveSampleHash
        self.postDriveSampleHash = postDriveSampleHash
        self.firstPreDriveSampleBitPattern = firstPreDriveSampleBitPattern
        self.firstPostDriveSampleBitPattern = firstPostDriveSampleBitPattern
        self.lastPreDriveSampleBitPattern = lastPreDriveSampleBitPattern
        self.lastPostDriveSampleBitPattern = lastPostDriveSampleBitPattern
        self.changedFrameIndex = changedFrameIndex
        self.changedPreDriveSampleBitPattern = changedPreDriveSampleBitPattern
        self.preDrivePeak = preDrivePeak
        self.preDrivePeakFrameIndex = preDrivePeakFrameIndex
        self.postDrivePeak = postDrivePeak
        self.postDrivePeakFrameIndex = postDrivePeakFrameIndex
        self.postDrivePeakPreDriveSample = postDrivePeakPreDriveSample
        self.postDrivePeakEffectiveAmount = postDrivePeakEffectiveAmount
        self.preDriveRMS = preDriveRMS
        self.postDriveRMS = postDriveRMS
        self.preDriveLowBandRMS = preDriveLowBandRMS
        self.postDriveLowBandRMS = postDriveLowBandRMS
        self.differenceRMS = differenceRMS
        self.interlockChapter = interlockChapter.rawValue
        self.bindingValid = bindingValid
        self.finite = finite
    }

    package init(
        _ evidence: PulseEchoReturnDriveRenderEvidence,
        interlockChapter: InterlockChapter,
        bindingValid: Bool
    ) {
        self.init(
            bar: evidence.bar,
            bpm: evidence.bpm,
            delayFrameCount: evidence.delayFrameCount,
            scoreEnabled: evidence.scoreEnabled,
            earliestPulseEchoOnsetStep: evidence.earliestPulseEchoOnsetStep,
            driveEligible: evidence.driveEligible,
            machineTexture: evidence.machineTexture,
            appliedAmount: evidence.appliedAmount,
            transitionFrameCount: evidence.transitionFrameCount,
            renderedFrameCount: evidence.renderedFrameCount,
            currentSendRMS: Double(evidence.currentSendRMS),
            preDriveSampleHash: evidence.preDriveSampleHash,
            postDriveSampleHash: evidence.postDriveSampleHash,
            firstPreDriveSampleBitPattern:
                evidence.firstPreDriveSampleBitPattern,
            firstPostDriveSampleBitPattern:
                evidence.firstPostDriveSampleBitPattern,
            lastPreDriveSampleBitPattern:
                evidence.lastPreDriveSampleBitPattern,
            lastPostDriveSampleBitPattern:
                evidence.lastPostDriveSampleBitPattern,
            changedFrameIndex: evidence.changedFrameIndex,
            changedPreDriveSampleBitPattern:
                evidence.changedPreDriveSampleBitPattern,
            preDrivePeak: Double(evidence.preDrivePeak),
            preDrivePeakFrameIndex: evidence.preDrivePeakFrameIndex,
            postDrivePeak: Double(evidence.postDrivePeak),
            postDrivePeakFrameIndex: evidence.postDrivePeakFrameIndex,
            postDrivePeakPreDriveSample:
                Double(evidence.postDrivePeakPreDriveSample),
            postDrivePeakEffectiveAmount:
                evidence.postDrivePeakEffectiveAmount,
            preDriveRMS: Double(evidence.preDriveRMS),
            postDriveRMS: Double(evidence.postDriveRMS),
            preDriveLowBandRMS: Double(evidence.preDriveLowBandRMS),
            postDriveLowBandRMS: Double(evidence.postDriveLowBandRMS),
            differenceRMS: Double(evidence.differenceRMS),
            interlockChapter: interlockChapter,
            bindingValid: bindingValid,
            finite: evidence.finite
        )
    }

    package var isFinite: Bool {
        finite && [
            bpm, machineTexture, appliedAmount, currentSendRMS,
            preDrivePeak, postDrivePeak, preDriveRMS, postDriveRMS,
            preDriveLowBandRMS, postDriveLowBandRMS, differenceRMS,
            postDrivePeakPreDriveSample, postDrivePeakEffectiveAmount,
        ].allSatisfy { $0.isFinite }
    }

    package func isComplete(
        sampleRate: Double,
        phraseKind: AutonomousPhraseKind,
        conservative: Bool,
        instruments: AutonomousInstrumentBarEvidence
    ) -> Bool {
        let sampleRateIsSupported = sampleRate >=
            QualityQualificationContract.minimumSupportedSampleRate &&
            sampleRate <= QualityQualificationContract.maximumSupportedSampleRate
        guard isFinite,
              bindingValid,
              bar >= 0,
              instruments.bar == bar,
              bpm == AutonomousSessionDirector.bpm,
              sampleRate.isFinite,
              sampleRateIsSupported,
              delayFrameCount == Self.delayFrames(
                bpm: bpm,
                sampleRate: sampleRate
              ),
              transitionFrameCount ==
                PulseEchoReturnDriveContract.transitionFrameCount(
                    sampleRate: sampleRate
                ),
              renderedFrameCount == Self.barFrames(
                bpm: bpm,
                sampleRate: sampleRate
              ),
              preDrivePeakFrameIndex >= 0,
              preDrivePeakFrameIndex < renderedFrameCount,
              postDrivePeakFrameIndex >= 0,
              postDrivePeakFrameIndex < renderedFrameCount,
              preDrivePeak == Double(Float(preDrivePeak)),
              postDrivePeakPreDriveSample ==
                Double(Float(postDrivePeakPreDriveSample)),
              let chapter = InterlockChapter(rawValue: interlockChapter),
              (0...1).contains(machineTexture),
              (0...Self.maximumAppliedAmount).contains(appliedAmount),
              earliestPulseEchoOnsetStep.map({ (0..<16).contains($0) }) ?? true,
              currentSendRMS >= 0,
              Self.isSampleHash(preDriveSampleHash),
              Self.isSampleHash(postDriveSampleHash),
              Float(bitPattern: firstPreDriveSampleBitPattern).isFinite,
              Float(bitPattern: firstPostDriveSampleBitPattern).isFinite,
              Float(bitPattern: lastPreDriveSampleBitPattern).isFinite,
              Float(bitPattern: lastPostDriveSampleBitPattern).isFinite,
              firstPreDriveSampleBitPattern == firstPostDriveSampleBitPattern,
              lastPreDriveSampleBitPattern == lastPostDriveSampleBitPattern,
              postDrivePeakEffectiveAmount == expectedPeakEffectiveAmount,
              postDrivePeak == expectedWitnessedPostDrivePeak,
              signalMetricsAreBounded else {
            return false
        }

        let hasPulseEchoAccess = hasPulseEchoAccess(in: instruments)
        guard hasPulseEchoAccess == (earliestPulseEchoOnsetStep != nil) else {
            return false
        }
        guard !hasPulseEchoAccess || scoreEnabled else { return false }
        guard currentSendRMS == 0 || (scoreEnabled && hasPulseEchoAccess) else {
            return false
        }
        guard hasPulseEchoAccess || (currentSendRMS == 0 && appliedAmount == 0) else {
            return false
        }

        let hasTimelyPulseEchoOnset = earliestPulseEchoOnsetStep.map {
            $0 <= PulseEchoTextureArticulation.latestDrivenOnsetStep
        } == true
        let normallyEligible = chapter == .memory && scoreEnabled &&
            hasPulseEchoAccess && hasTimelyPulseEchoOnset && !conservative &&
            phraseKind != .identityReturn && phraseKind != .majorBreak
        guard !driveEligible || normallyEligible else { return false }
        let expectedAmount = driveEligible
            ? min(Self.maximumAppliedAmount, machineTexture) : 0
        guard appliedAmount == expectedAmount else { return false }
        if driveEligible && appliedAmount > 0 {
            guard currentSendRMS > 0,
                  preDrivePeak > 0,
                  preDriveRMS > 0 else {
                return false
            }
        }

        let inputIsZero = preDrivePeak == 0 && preDriveRMS == 0 &&
            preDriveLowBandRMS == 0
        let outputIsZero = postDrivePeak == 0 && postDriveRMS == 0 &&
            postDriveLowBandRMS == 0
        guard (preDrivePeak == 0) == (preDriveRMS == 0),
              (postDrivePeak == 0) == (postDriveRMS == 0),
              preDrivePeak != 0 || preDriveLowBandRMS == 0,
              postDrivePeak != 0 || postDriveLowBandRMS == 0 else {
            return false
        }
        if appliedAmount == 0 || inputIsZero {
            guard preDriveSampleHash == postDriveSampleHash,
                  preDrivePeak == postDrivePeak,
                  preDriveRMS == postDriveRMS,
                  preDriveLowBandRMS == postDriveLowBandRMS,
                  differenceRMS == 0,
                  !inputIsZero || outputIsZero else {
                return false
            }
        }
        if appliedAmount > 0 {
            guard changedFrameIndex >= 0,
                  changedFrameIndex < renderedFrameCount,
                  Float(bitPattern: changedPreDriveSampleBitPattern).isFinite,
                  changedWitnessPreDriveMagnitude <= preDrivePeak,
                  changedWitnessPostDriveMagnitude <= postDrivePeak,
                  changedWitnessChangesBitPattern,
                  preDriveSampleHash != postDriveSampleHash,
                  differenceRMS > 0 else {
                return false
            }
        } else {
            guard changedFrameIndex == -1,
                  changedPreDriveSampleBitPattern == 0 else {
                return false
            }
        }
        if differenceRMS == 0 {
            guard preDriveSampleHash == postDriveSampleHash,
                  preDrivePeak == postDrivePeak,
                  preDriveRMS == postDriveRMS,
                  preDriveLowBandRMS == postDriveLowBandRMS else {
                return false
            }
        }
        if driveEligible && expectedPostDriveMagnitudeAtPreDrivePeak != preDrivePeak {
            guard preDriveSampleHash != postDriveSampleHash,
                  differenceRMS > 0 else {
                return false
            }
        }
        return true
    }

    private var expectedPeakEffectiveAmount: Double {
        PulseEchoReturnDriveContract.effectiveAmount(
            targetAmount: appliedAmount,
            frame: postDrivePeakFrameIndex,
            totalFrameCount: renderedFrameCount,
            transitionFrameCount: transitionFrameCount
        )
    }

    private var expectedWitnessedPostDrivePeak: Double {
        abs(Double(PulseEchoReturnDriveContract.process(
            preDriveSample: Float(postDrivePeakPreDriveSample),
            amount: postDrivePeakEffectiveAmount
        )))
    }

    private var changedWitnessChangesBitPattern: Bool {
        changedWitnessPostDriveSample.bitPattern !=
            changedPreDriveSampleBitPattern
    }

    private var changedWitnessPreDriveMagnitude: Double {
        abs(Double(Float(bitPattern: changedPreDriveSampleBitPattern)))
    }

    private var changedWitnessPostDriveMagnitude: Double {
        abs(Double(changedWitnessPostDriveSample))
    }

    private var changedWitnessPostDriveSample: Float {
        let preDriveSample = Float(bitPattern: changedPreDriveSampleBitPattern)
        let effectiveAmount = PulseEchoReturnDriveContract.effectiveAmount(
            targetAmount: appliedAmount,
            frame: changedFrameIndex,
            totalFrameCount: renderedFrameCount,
            transitionFrameCount: transitionFrameCount
        )
        return PulseEchoReturnDriveContract.process(
            preDriveSample: preDriveSample,
            amount: effectiveAmount
        )
    }

    private var preDrivePeakEffectiveAmount: Double {
        PulseEchoReturnDriveContract.effectiveAmount(
            targetAmount: appliedAmount,
            frame: preDrivePeakFrameIndex,
            totalFrameCount: renderedFrameCount,
            transitionFrameCount: transitionFrameCount
        )
    }

    private var expectedPostDriveMagnitudeAtPreDrivePeak: Double {
        abs(Double(PulseEchoReturnDriveContract.process(
            preDriveSample: Float(preDrivePeak),
            amount: preDrivePeakEffectiveAmount
        )))
    }

    private var conservativePostDrivePeakCap: Double {
        min(
            preDrivePeak * PulseEchoReturnDriveContract.maximumLowLevelGain,
            max(preDrivePeak, PulseEchoReturnDriveContract.normalizationAmplitude)
        )
    }

    package func normalDriveEligibility(
        phraseKind: AutonomousPhraseKind,
        conservative: Bool,
        instruments: AutonomousInstrumentBarEvidence
    ) -> Bool {
        interlockChapter == InterlockChapter.memory.rawValue && scoreEnabled &&
            hasPulseEchoAccess(in: instruments) &&
            earliestPulseEchoOnsetStep.map {
                $0 <= PulseEchoTextureArticulation.latestDrivenOnsetStep
            } == true && !conservative &&
            phraseKind != .identityReturn && phraseKind != .majorBreak
    }

    private var signalMetricsAreBounded: Bool {
        let tolerance = Self.metricTolerance
        let maximum = Double(Float.greatestFiniteMagnitude)
        return [
            currentSendRMS, preDrivePeak, postDrivePeak, preDriveRMS,
            postDriveRMS, preDriveLowBandRMS, postDriveLowBandRMS,
            differenceRMS, abs(postDrivePeakPreDriveSample),
            postDrivePeakEffectiveAmount,
        ].allSatisfy { (0...maximum).contains($0) } &&
            abs(postDrivePeakPreDriveSample) <= preDrivePeak &&
            postDrivePeakEffectiveAmount <= appliedAmount &&
            preDriveRMS <= preDrivePeak + tolerance &&
            postDriveRMS <= postDrivePeak + tolerance &&
            postDriveRMS <= preDriveRMS *
                PulseEchoReturnDriveContract.maximumLowLevelGain + tolerance &&
            preDriveLowBandRMS <= preDriveRMS + tolerance &&
            postDriveLowBandRMS <= postDriveRMS + tolerance &&
            postDrivePeak >= expectedPostDriveMagnitudeAtPreDrivePeak &&
            postDrivePeak <= conservativePostDrivePeakCap + tolerance &&
            differenceRMS + tolerance >= abs(preDriveRMS - postDriveRMS) &&
            differenceRMS <= preDriveRMS + postDriveRMS + tolerance
    }

    private static func delayFrames(bpm: Double, sampleRate: Double) -> Int {
        max(1, Int((60.0 / bpm * 0.75 * sampleRate).rounded()))
    }

    private static func barFrames(bpm: Double, sampleRate: Double) -> Int {
        max(1, Int((240.0 / bpm * sampleRate).rounded()))
    }

    private func hasPulseEchoAccess(
        in instruments: AutonomousInstrumentBarEvidence
    ) -> Bool {
        instruments.architectures.contains { architecture in
            architecture.assignments.contains { assignment in
                assignment.effects.contains(InstrumentEffect.pulseEcho.rawValue)
            }
        }
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

package struct AutonomousGraphEvidence: Codable, Equatable, Sendable {
    package static let maximumViolationCount = 64

    package let graphFingerprint: String
    package let revision: Int
    package let nodeCount: Int
    package let branchCount: Int
    package let maximumDepth: Int
    package let lowEndProtected: Bool
    package let protectedRoutingValid: Bool
    package let validationValid: Bool
    package let sourceViolationCount: Int
    package let violations: [String]
    package let mutationKind: String?
    package let mutatedNodeCount: Int

    package init(
        graphFingerprint: String,
        revision: Int,
        nodeCount: Int,
        branchCount: Int,
        maximumDepth: Int,
        lowEndProtected: Bool,
        protectedRoutingValid: Bool,
        validationValid: Bool,
        sourceViolationCount: Int,
        violations: [String],
        mutationKind: String?,
        mutatedNodeCount: Int
    ) {
        self.graphFingerprint = graphFingerprint
        self.revision = revision
        self.nodeCount = nodeCount
        self.branchCount = branchCount
        self.maximumDepth = maximumDepth
        self.lowEndProtected = lowEndProtected
        self.protectedRoutingValid = protectedRoutingValid
        self.validationValid = validationValid
        self.sourceViolationCount = sourceViolationCount
        self.violations = Array(violations.prefix(Self.maximumViolationCount))
        self.mutationKind = mutationKind
        self.mutatedNodeCount = mutatedNodeCount
    }

    package var isComplete: Bool {
        guard !graphFingerprint.isEmpty, revision >= 0, nodeCount >= 0,
              nodeCount <= DSPGraphPlan.maximumNodeCount, branchCount >= 0,
              branchCount <= DSPGraphPlan.maximumBranchCount,
              maximumDepth >= 0,
              maximumDepth <= DSPGraphPlan.maximumSerialDepth,
              sourceViolationCount == violations.count,
              sourceViolationCount <= Self.maximumViolationCount,
              mutatedNodeCount >= 0, mutatedNodeCount <= 2 else {
            return false
        }
        let summarizedValidationValid = lowEndProtected && protectedRoutingValid &&
            nodeCount > 0 && branchCount > 0 && maximumDepth > 0 &&
            branchCount <= nodeCount && maximumDepth <= nodeCount &&
            maximumDepth <= nodeCount - branchCount + 1 &&
            nodeCount <= branchCount * maximumDepth && violations.isEmpty
        let mutationIsConsistent: Bool
        if let mutationKind {
            guard let kind = DSPGraphMutationKind(rawValue: mutationKind),
                  revision > 0 else { return false }
            switch kind {
            case .reorder:
                mutationIsConsistent = mutatedNodeCount == 2
            case .insert, .bypass, .replace, .rerouteSend:
                mutationIsConsistent = mutatedNodeCount == 1
            }
        } else {
            mutationIsConsistent = mutatedNodeCount == 0
        }
        return validationValid == summarizedValidationValid &&
            validationValid == violations.isEmpty && mutationIsConsistent
    }
}

package struct AutonomousRouteContinuationEvidence: Codable, Equatable, Sendable {
    package let sampleRate: Double
    package let channelCount: Int
    package let routeGeneration: Int
    package let routeFingerprint: String
    package let incomingContinuationFingerprint: String
    package let incomingQualityStateFingerprint: String
    package let incomingKickCorrectionDB: Double
    package let incomingTopologyRevision: Int
    package let previousGraphFingerprint: String
    package let routeRecovery: Bool
    /// Exact render + generated-DSP continuation after this candidate render,
    /// before the selected quality decision is finalized. Quality is excluded
    /// deliberately to avoid a transaction-fingerprint cycle.
    package let outgoingRenderDSPFingerprint: String
    package let controllerStateFingerprint: String

    package init(
        sampleRate: Double,
        channelCount: Int = 2,
        routeGeneration: Int,
        routeFingerprint: String,
        incomingContinuationFingerprint: String,
        incomingQualityStateFingerprint: String,
        incomingKickCorrectionDB: Double,
        incomingTopologyRevision: Int,
        previousGraphFingerprint: String,
        routeRecovery: Bool,
        outgoingRenderDSPFingerprint: String,
        controllerStateFingerprint: String
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.routeGeneration = routeGeneration
        self.routeFingerprint = routeFingerprint
        self.incomingContinuationFingerprint = incomingContinuationFingerprint
        self.incomingQualityStateFingerprint = incomingQualityStateFingerprint
        self.incomingKickCorrectionDB = incomingKickCorrectionDB
        self.incomingTopologyRevision = incomingTopologyRevision
        self.previousGraphFingerprint = previousGraphFingerprint
        self.routeRecovery = routeRecovery
        self.outgoingRenderDSPFingerprint = outgoingRenderDSPFingerprint
        self.controllerStateFingerprint = controllerStateFingerprint
    }

    package var isFinite: Bool {
        sampleRate.isFinite && incomingKickCorrectionDB.isFinite
    }

    package var isComplete: Bool {
        sampleRate >= QualityQualificationContract.minimumSupportedSampleRate &&
            sampleRate <= QualityQualificationContract.maximumSupportedSampleRate &&
            channelCount == QualityQualificationContract.requiredRouteChannelCount &&
            routeGeneration >= 0 &&
            !routeFingerprint.isEmpty &&
            !incomingContinuationFingerprint.isEmpty &&
            !incomingQualityStateFingerprint.isEmpty &&
            (AutomaticMixBalancer.minimumKickCorrectionDB...0).contains(
                incomingKickCorrectionDB
            ) && incomingTopologyRevision >= 0 &&
            incomingTopologyRevision < Int.max &&
            !previousGraphFingerprint.isEmpty &&
            !outgoingRenderDSPFingerprint.isEmpty &&
            !controllerStateFingerprint.isEmpty &&
            routeFingerprint == AutonomousCandidateFingerprint.route(
                sampleRate: sampleRate,
                channelCount: channelCount,
                generation: routeGeneration
            )
    }
}

/// The complete reduced evidence vector for one immutable candidate render.
/// Raw PCM and renderer state never enter this value.
package struct AutonomousCandidateEvaluationVector: Codable, Equatable, Sendable {
    package static let schemaVersion = 9
    package static let maximumBarCount = 16
    package static let maximumMaskingObservationsPerBar = 12
    package static let maximumStemRolesPerBar = 5
    package static let maximumGroovePulseEventsPerBar = 8
    package static let maximumClosedHatEventsPerBar = 4
    package static let maximumInstrumentArchitecturesPerBar = 3
    package static let maximumInstrumentAssignmentsPerArchitecture = 6
    package static let maximumInstrumentEventsPerBar = 64
    package static let maximumUpperTimingEventsPerBar = 64

    package let schemaVersion: Int
    package let slot: AutonomousCandidateSlot
    package let planFingerprint: String
    package let graphFingerprint: String
    package let symbolic: AutonomousSymbolicEvidence
    package let hardGates: AutonomousHardGateEvidence
    package let fullMix: AutonomousFullMixEvidence
    package let sourceMaskingBarCount: Int
    package let masking: [AutonomousMaskingBarEvidence]
    package let sourceStemBarCount: Int
    package let stems: [AutonomousStemBarEvidence]
    package let sourceAutomaticMixBarCount: Int
    package let automaticMix: [AutonomousAutomaticMixEvidence]
    package let sourceKickSyntaxBarCount: Int
    package let kickSyntax: [AutonomousKickSyntaxBarEvidence]
    package let sourceGroovePulseBarCount: Int
    package let groovePulse: [AutonomousGroovePulseBarEvidence]
    package let sourceClosedHatBarCount: Int
    package let closedHat: [AutonomousClosedHatBarEvidence]
    package let sourceInstrumentBarCount: Int
    package let instruments: [AutonomousInstrumentBarEvidence]
    package let sourcePulseEchoDriveBarCount: Int
    package let pulseEchoDrive: [AutonomousPulseEchoDriveBarEvidence]
    package let sourceUpperTimingBarCount: Int
    package let upperTiming: [AutonomousUpperTimingBarEvidence]
    package let graph: AutonomousGraphEvidence
    package let routeContinuation: AutonomousRouteContinuationEvidence
    /// Aggregate over the exact graph-input remainder. This diagnoses whether
    /// a deficit existed before the generated topology.
    package let preGraphUpperTimbreEvidence: UpperTimbreEvidence
    /// Aggregate over the post-graph remainder. Existing playback hard gates
    /// continue to use this observation.
    package let postGraphUpperTimbreEvidence: UpperTimbreEvidence

    package init(
        slot: AutonomousCandidateSlot,
        planFingerprint: String,
        graphFingerprint: String,
        symbolic: AutonomousSymbolicEvidence,
        hardGates: AutonomousHardGateEvidence,
        fullMix: AutonomousFullMixEvidence,
        masking: [AutonomousMaskingBarEvidence],
        stems: [AutonomousStemBarEvidence],
        automaticMix: [AutonomousAutomaticMixEvidence],
        kickSyntax: [AutonomousKickSyntaxBarEvidence],
        groovePulse: [AutonomousGroovePulseBarEvidence],
        closedHat: [AutonomousClosedHatBarEvidence] = [],
        instruments: [AutonomousInstrumentBarEvidence],
        pulseEchoDrive: [AutonomousPulseEchoDriveBarEvidence],
        upperTiming: [AutonomousUpperTimingBarEvidence],
        graph: AutonomousGraphEvidence,
        routeContinuation: AutonomousRouteContinuationEvidence,
        preGraphUpperTimbreEvidence: UpperTimbreEvidence,
        postGraphUpperTimbreEvidence: UpperTimbreEvidence
    ) {
        schemaVersion = Self.schemaVersion
        self.slot = slot
        self.planFingerprint = planFingerprint
        self.graphFingerprint = graphFingerprint
        self.symbolic = symbolic
        self.hardGates = hardGates
        self.fullMix = fullMix
        sourceMaskingBarCount = masking.count
        self.masking = Array(masking.prefix(Self.maximumBarCount))
        sourceStemBarCount = stems.count
        self.stems = Array(stems.prefix(Self.maximumBarCount))
        sourceAutomaticMixBarCount = automaticMix.count
        self.automaticMix = Array(automaticMix.prefix(Self.maximumBarCount))
        sourceKickSyntaxBarCount = kickSyntax.count
        self.kickSyntax = Array(kickSyntax.prefix(Self.maximumBarCount))
        sourceGroovePulseBarCount = groovePulse.count
        self.groovePulse = Array(groovePulse.prefix(Self.maximumBarCount))
        sourceClosedHatBarCount = closedHat.count
        self.closedHat = Array(closedHat.prefix(Self.maximumBarCount))
        sourceInstrumentBarCount = instruments.count
        self.instruments = Array(instruments.prefix(Self.maximumBarCount))
        sourcePulseEchoDriveBarCount = pulseEchoDrive.count
        self.pulseEchoDrive = Array(pulseEchoDrive.prefix(Self.maximumBarCount))
        sourceUpperTimingBarCount = upperTiming.count
        self.upperTiming = Array(upperTiming.prefix(Self.maximumBarCount))
        self.graph = graph
        self.routeContinuation = routeContinuation
        self.preGraphUpperTimbreEvidence = preGraphUpperTimbreEvidence
        self.postGraphUpperTimbreEvidence = postGraphUpperTimbreEvidence
    }

    package static func make(
        slot: AutonomousCandidateSlot,
        plan: AutonomousPhrasePlan,
        graph: DSPGraphPlan,
        planFingerprint: String,
        graphFingerprint: String,
        blocks: [RenderBlock],
        audioPreflight: PhraseAudioPreflight,
        upperTimbreEvidence: UpperTimbreEvidence,
        sampleRate: Double,
        routeChannelCount: Int,
        routeGeneration: Int,
        routeFingerprint: String,
        incomingContinuationFingerprint: String,
        incomingQualityStateFingerprint: String,
        incomingKickCorrectionDB: Double,
        incomingTopologyRevision: Int,
        previousGraphFingerprint: String,
        routeRecovery: Bool,
        outgoingRenderDSPFingerprint: String,
        controllerStateFingerprint: String,
        cancellationRequested: @escaping @Sendable () -> Bool
    ) -> AutonomousCandidateEvaluationVector? {
        guard !cancellationRequested() else { return nil }
        let boundedBlocks = Array(blocks.prefix(maximumBarCount))
        let preGraphUpperTimbreEvidence = UpperTimbreEvidence.aggregating(
            boundedBlocks.map { $0.graphInputRemainderTimbreEvidence }
        )
        let graphValidation = DSPGraphValidator.validate(graph)
        let completeInputs = !blocks.isEmpty && blocks.count <= maximumBarCount &&
            plan.barCount == plan.resolvedBars.count && plan.barCount == blocks.count &&
            audioPreflight.bars.count == blocks.count
        let channelsAligned = boundedBlocks.allSatisfy {
            !$0.left.isEmpty && $0.left.count == $0.right.count
        }
        var samplesFinite = true
        for block in boundedBlocks {
            guard !cancellationRequested() else { return nil }
            if !block.left.allSatisfy({ $0.isFinite }) ||
                !block.right.allSatisfy({ $0.isFinite }) {
                samplesFinite = false
                break
            }
        }

        let chapters = plan.resolvedBars.map { $0.interlockChapter }
        let internalChapterChange = zip(chapters, chapters.dropFirst()).contains {
            $0 != $1
        }
        let boundaryAtPhraseStart = plan.startBar > 0 &&
            plan.startBar.isMultiple(of: 16)
        let startBoundaryChanged = boundaryAtPhraseStart &&
            plan.endingInterlockState.previousChapters.last.map {
                $0 != chapters.first
            } == true
        let symbolic = AutonomousSymbolicEvidence(
            planFingerprint: planFingerprint,
            phraseIndex: plan.phraseIndex,
            startBar: plan.startBar,
            declaredBarCount: plan.barCount,
            resolvedBarCount: plan.resolvedBars.count,
            phraseKind: plan.kind.rawValue,
            pulseClarity: plan.interest.pulseClarity,
            intentionalSpace: plan.interest.intentionalSpace,
            responseClosure: plan.interest.responseClosure,
            structuralTimeliness: plan.interest.structuralTimeliness,
            identityContinuity: plan.interest.identityContinuity,
            weakPositionCoverage: plan.interest.weakPositionCoverage,
            trailingSideRelationship: plan.interest.trailingSideRelationship,
            overactivityPenalty: plan.interest.overactivityPenalty,
            overdueDebtCount: plan.interest.overdueDebtCount,
            interestScore: plan.interest.score,
            interestValid: plan.interest.valid,
            chapterChanged: internalChapterChange || startBoundaryChanged,
            alternate: plan.alternate,
            conservative: plan.conservative,
            boundsValid: completeInputs
        )
        let hardGates = AutonomousHardGateEvidence(
            symbolicValid: plan.interest.valid,
            graphValid: graphValidation.valid,
            audioSafetyValid: audioPreflight.safetyValid,
            fullMixFinite: audioPreflight.quality.finite,
            upperTimbreFinite: upperTimbreEvidence.finite,
            blocksPresent: !blocks.isEmpty,
            blockChannelsAligned: channelsAligned,
            allSamplesFinite: samplesFinite,
            completeInputs: completeInputs
        )
        let fullMix = AutonomousFullMixEvidence(
            sourceBarCount: audioPreflight.bars.count,
            analyzedFrameCount: audioPreflight.quality.analyzedFrameCount,
            sampleHash: audioPreflight.quality.sampleHash,
            peak: Double(audioPreflight.quality.peak),
            truePeakEstimate: Double(audioPreflight.quality.truePeakEstimate),
            rms: Double(audioPreflight.quality.rms),
            loudnessEstimate: Double(audioPreflight.quality.loudnessEstimate),
            maximumMomentaryLoudness:
                audioPreflight.quality.musical.maximumMomentaryLoudness,
            maximumShortTermLoudness:
                audioPreflight.quality.musical.maximumShortTermLoudness,
            loudnessRange: audioPreflight.quality.musical.loudnessRange,
            momentaryBlockCount:
                audioPreflight.quality.musical.momentaryBlockCount,
            absoluteGatedBlockCount:
                audioPreflight.quality.musical.absoluteGatedBlockCount,
            relativeGatedBlockCount:
                audioPreflight.quality.musical.relativeGatedBlockCount,
            shortTermBlockCount:
                audioPreflight.quality.musical.shortTermBlockCount,
            dcOffset: Double(audioPreflight.quality.dcOffset),
            stereoCorrelation: Double(audioPreflight.quality.stereoCorrelation),
            lowStereoCorrelation: Double(audioPreflight.quality.lowStereoCorrelation),
            maximumBoundaryDelta: Double(audioPreflight.quality.maxBoundaryDelta),
            movementScore: audioPreflight.movementScore,
            analysisPeakWorkingByteCount:
                audioPreflight.quality.analysisPeakWorkingByteCount,
            perceptual: audioPreflight.quality.musical.perceptualEvidence,
            bars: audioPreflight.bars.prefix(maximumBarCount).map {
                AutonomousBarFullMixEvidence(
                    bar: $0.bar,
                    loudness: $0.loudness,
                    spectralCentroid: $0.spectralCentroid,
                    transientDensity: $0.transientDensity,
                    crestFactor: $0.crestFactor,
                    finite: $0.finite
                )
            }
        )
        let masking = boundedBlocks.map { block in
            let observations = block.masking.prefix(maximumMaskingObservationsPerBar).map {
                AutonomousMaskingObservationEvidence(
                    bandName: $0.band.name,
                    lowerHz: $0.band.lowerHz,
                    upperHz: $0.band.upperHz,
                    firstRole: $0.firstRole.rawValue,
                    secondRole: $0.secondRole.rawValue,
                    analyzedWindowCount: $0.analyzedWindowCount,
                    activePairWindowCount: $0.activePairWindowCount,
                    overlapWindowCount: $0.overlapWindowCount,
                    longestOverlapRun: $0.longestOverlapRun,
                    maximumOverlap: $0.maximumOverlap
                )
            }
            return AutonomousMaskingBarEvidence(
                bar: block.bar,
                sourceObservationCount: block.masking.count,
                observations: Array(observations)
            )
        }
        let stems = boundedBlocks.map { block in
            let roles = MixRole.allCases.compactMap { role -> AutonomousRoleStemEvidence? in
                guard let observation = block.stemObservations[role] else { return nil }
                return AutonomousRoleStemEvidence(
                    role: role.rawValue,
                    rms: observation.rms,
                    activeRMS: observation.activeRMS,
                    onsetRMS: observation.onsetRMS,
                    peak: observation.peak,
                    crestFactor: observation.crestFactor,
                    occupancy: observation.occupancy,
                    bands: MixBand.allCases.map {
                        AutonomousStemBandEvidence(
                            band: $0.rawValue,
                            energy: observation.bandEnergy[$0] ?? .nan
                        )
                    }
                )
            }
            return AutonomousStemBarEvidence(
                bar: block.bar,
                sourceRoleCount: block.stemObservations.count,
                roles: roles
            )
        }
        let automaticMix = boundedBlocks.map { block in
            let companion = plan.resolvedBars.first {
                $0.performance.bar == block.bar
            }?.foundationCompanion.rawValue ?? ""
            return AutonomousAutomaticMixEvidence(
                bar: block.bar,
                section: block.section.rawValue,
                foundationCompanion: companion,
                gains: MixRole.allCases.map {
                    AutonomousRoleGainEvidence(
                        role: $0.rawValue,
                        gainDB: block.automaticMix.gainsDB[$0] ?? .nan
                    )
                },
                measuredKickOverFoundationDB: block.automaticMix.measuredKickOverFoundationDB,
                targetKickOverFoundationDB: block.automaticMix.targetKickOverFoundationDB
            )
        }
        var kickSyntax: [AutonomousKickSyntaxBarEvidence] = []
        kickSyntax.reserveCapacity(boundedBlocks.count)
        for (index, block) in boundedBlocks.enumerated() {
            guard !cancellationRequested() else { return nil }
            let scoreKickSteps = block.resolvedPerformance.ensemble.events
                .filter { $0.voice == .kick }
                .map(\.step)
                .sorted()
            let scoreKickStepMask = kickStepMask(scoreKickSteps)
            let resolvedPlanBar = plan.resolvedBars.indices.contains(index)
                ? plan.resolvedBars[index] : nil
            let role = block.resolvedPerformance.kickSyntaxRole
            let mix = block.kickMix
            let expectedAudibleGain = KickMixBalance.audibleGain * Double(
                Float(block.automaticMix.gain(for: .kick))
            )
            let kickStem = block.stemObservations[.kick]
            let scoreRoleMatches: Bool = switch role {
            case .withheld:
                scoreKickSteps.isEmpty &&
                    block.resolvedPerformance.ensemble.kickAnchors.isEmpty
            case .grounded, .recovery:
                !scoreKickSteps.isEmpty &&
                    scoreKickSteps == block.resolvedPerformance.ensemble.kickAnchors
            }
            let kickStemMatches = kickStem.map {
                $0.peak == mix.audiblePeak && $0.rms == mix.audibleRMS
            } ?? false
            let withheldContextMatches = role != .withheld || (
                block.resolvedPerformance.groovePulses.map(\.step) ==
                    KickSyntaxResolver.canonicalWeakPulseSteps &&
                block.resolvedPerformance.ensemble.events.contains {
                    $0.voice == .motif
                } &&
                block.instrumentRenderEvidence.contains { architecture in
                    architecture.assignments.contains { $0.use == .motif }
                }
            )
            let syntaxAuthorizationMatches = role == .grounded || (
                plan.kind == .energyRelease && !plan.conservative &&
                    !plan.paidDebtIDs.isEmpty
            )
            let planBarMatches = resolvedPlanBar.map {
                $0 == block.resolvedPerformance && $0.performance.bar == block.bar
            } ?? false
            let kickMaskMatches = scoreKickStepMask.map {
                $0 == mix.renderedKickStepMask
            } ?? false
            let bindingValid = planBarMatches &&
                block.section == block.resolvedPerformance.performance.section &&
                block.left.count == block.right.count &&
                mix.renderedFrameCount == block.left.count &&
                scoreKickSteps == block.resolvedPerformance.ensemble.kickAnchors &&
                scoreRoleMatches &&
                mix.renderedKickEventCount == scoreKickSteps.count &&
                kickMaskMatches &&
                mix.audibleGain == expectedAudibleGain &&
                mix.detectorToAudibleScaleMatches &&
                block.kickRenderPassesMatch && kickStemMatches &&
                withheldContextMatches && syntaxAuthorizationMatches
            kickSyntax.append(AutonomousKickSyntaxBarEvidence(
                bar: block.bar,
                role: role,
                scoreKickEventCount: scoreKickSteps.count,
                scoreKickStepMask: scoreKickStepMask ?? 0,
                renderedKickEventCount: mix.renderedKickEventCount,
                renderedKickStepMask: mix.renderedKickStepMask,
                renderedFrameCount: mix.renderedFrameCount,
                audibleGain: mix.audibleGain,
                detectorPeak: mix.detectorPeak,
                detectorRMS: mix.detectorRMS,
                audiblePeak: mix.audiblePeak,
                audibleRMS: mix.audibleRMS,
                duckingEnvelopePeak: mix.duckingEnvelopePeak,
                detectorSampleHash: mix.detectorSampleHash,
                audibleSampleHash: mix.audibleSampleHash,
                detectorNonzeroSampleCount: mix.detectorNonzeroSampleCount,
                audibleNonzeroSampleCount: mix.audibleNonzeroSampleCount,
                detectorToAudibleScaleMatches:
                    mix.detectorToAudibleScaleMatches,
                renderPassesMatch: block.kickRenderPassesMatch,
                bindingValid: bindingValid
            ))
        }
        let groovePulse = boundedBlocks.map { block in
            let score = block.resolvedPerformance.groovePulses
            let rendered = block.groovePulseRenderEvidence
            let matched = rendered.compactMap {
                evidence -> AutonomousGroovePulseEventEvidence? in
                let matchingScoreEvents = score.filter { $0.step == evidence.step }
                guard matchingScoreEvents.count == 1,
                      let articulation = matchingScoreEvents.first,
                evidence.intensity == articulation.intensity,
                evidence.strikeZone == articulation.strikeZone,
                evidence.damping == articulation.damping,
                evidence.timbreMicrovariation == articulation.timbreMicrovariation else {
                    return nil
                }
                return AutonomousGroovePulseEventEvidence(
                    step: evidence.step,
                    intensity: evidence.intensity,
                    strikeZone: evidence.strikeZone.rawValue,
                    damping: evidence.damping,
                    timbreMicrovariation: evidence.timbreMicrovariation,
                    renderedFrameCount: evidence.renderedFrameCount,
                    sampleHash: evidence.sampleHash,
                    sourceRMS: evidence.rms,
                    spectralCentroidHz: evidence.spectralCentroidHz,
                    tailToAttackDB: evidence.tailToAttackDB,
                    finite: evidence.finite
                )
            }.sorted { $0.step < $1.step }
            return AutonomousGroovePulseBarEvidence(
                bar: block.bar,
                sourceScoreEventCount: score.count,
                sourceRenderEventCount: rendered.count,
                events: matched
            )
        }
        let closedHat = boundedBlocks.map { block in
            let score = block.resolvedPerformance.ensemble.events.enumerated()
                .filter { $0.element.voice == .percussion }
            let rendered = block.closedHatRenderEvidence
            let matched = rendered.compactMap {
                evidence -> AutonomousClosedHatEventEvidence? in
                guard score.contains(where: {
                    $0.offset == evidence.scoreEventIndex
                }),
                block.resolvedPerformance.ensemble.events.indices.contains(
                    evidence.scoreEventIndex
                ) else {
                    return nil
                }
                let event = block.resolvedPerformance.ensemble.events[
                    evidence.scoreEventIndex
                ]
                guard event.voice == .percussion,
                      let articulation = block.resolvedPerformance.closedHatDecay(
                        atEventIndex: evidence.scoreEventIndex
                      ),
                      articulation.step == event.step,
                      articulation.role == evidence.role,
                      evidence.step == event.step,
                      evidence.eventIntensity == event.intensity,
                      evidence.relocated == event.relocated else {
                    return nil
                }
                let expectedTiming = VoiceRenderer.timingOffsetInSteps(
                    for: event.voice,
                    step: event.step,
                    dna: block.sceneDNA
                )
                let combinedAccent = block.resolvedPerformance.performance.accent(
                    at: event.step
                ) * event.intensity
                let scoreSection = block.resolvedPerformance.performance.section
                guard evidence.timingOffsetInSteps == expectedTiming,
                      ClosedHatVoiceContract.appliedParametersMatch(
                        level: evidence.appliedLevel,
                        decayRate: evidence.appliedDecayRate,
                        brightness: plan.scene.character.percussionBrightness,
                        reportedSection: block.section,
                        scoreSection: scoreSection,
                        combinedAccent: combinedAccent,
                        role: evidence.role
                      ) else {
                    return nil
                }
                let decayRateScale = switch evidence.role {
                case .neutral: 1.0
                case .openHatCompanion:
                    ClosedHatVoiceContract.openHatCompanionDecayRateScale
                }
                return AutonomousClosedHatEventEvidence(
                    scoreEventIndex: evidence.scoreEventIndex,
                    step: evidence.step,
                    role: evidence.role.rawValue,
                    intensity: evidence.eventIntensity,
                    timingOffsetInSteps: evidence.timingOffsetInSteps,
                    relocated: evidence.relocated,
                    decayRateScale: decayRateScale,
                    renderedFrameCount: evidence.renderedFrameCount,
                    sampleHash: evidence.sampleHash,
                    sourceRMS: evidence.rms,
                    spectralCentroidHz: evidence.spectralCentroidHz,
                    tailToAttackDB: evidence.tailToAttackDB,
                    finite: evidence.finite
                )
            }.sorted { $0.scoreEventIndex < $1.scoreEventIndex }
            return AutonomousClosedHatBarEvidence(
                bar: block.bar,
                sourceScoreEventCount: score.count,
                sourceRenderEventCount: rendered.count,
                events: matched
            )
        }
        let instruments = boundedBlocks.map { block in
            AutonomousInstrumentBarEvidence(
                bar: block.bar,
                evidence: block.instrumentRenderEvidence
            )
        }
        let pulseEchoDrive = boundedBlocks.map { block in
            let evidence = block.pulseEchoReturnDriveRenderEvidence
            let articulation =
                block.synthPerformance.pulseEchoTextureArticulation
            let earliestPulseEchoOnsetStep = block.synthPerformance.upperNotes
                .filter { $0.instrument.effects.contains(.pulseEcho) }
                .map { $0.onsetStep }
                .min()
            let bindingValid = evidence.bar == block.bar &&
                evidence.bpm == plan.scene.bpm &&
                evidence.machineTexture == plan.scene.machineTexture &&
                evidence.scoreEnabled ==
                    block.resolvedPerformance.pulseEchoEnabled &&
                evidence.earliestPulseEchoOnsetStep ==
                    articulation.earliestPulseEchoOnsetStep &&
                evidence.earliestPulseEchoOnsetStep ==
                    earliestPulseEchoOnsetStep &&
                evidence.driveEligible == articulation.driveEligible &&
                evidence.appliedAmount == articulation.appliedAmount &&
                evidence.renderedFrameCount == block.left.count &&
                evidence.renderedFrameCount == block.right.count
            return AutonomousPulseEchoDriveBarEvidence(
                evidence,
                interlockChapter: block.resolvedPerformance.interlockChapter,
                bindingValid: bindingValid
            )
        }
        let upperTiming = boundedBlocks.map { block in
            makeUpperTimingEvidence(
                block: block,
                planBPM: plan.scene.bpm,
                routeSampleRate: sampleRate
            )
        }
        let graphEvidence = AutonomousGraphEvidence(
            graphFingerprint: graphFingerprint,
            revision: graph.revision,
            nodeCount: graph.nodes.count,
            branchCount: graph.branchCount,
            maximumDepth: graph.maximumDepth,
            lowEndProtected: graph.lowEndProtected,
            protectedRoutingValid: graph.protectedRouting.valid,
            validationValid: graphValidation.valid,
            sourceViolationCount: graphValidation.violations.count,
            violations: graphValidation.violations,
            mutationKind: graph.mutation?.kind.rawValue,
            mutatedNodeCount: graph.mutation?.affectedNodeIDs.count ?? 0
        )
        let route = AutonomousRouteContinuationEvidence(
            sampleRate: sampleRate,
            channelCount: routeChannelCount,
            routeGeneration: routeGeneration,
            routeFingerprint: routeFingerprint,
            incomingContinuationFingerprint: incomingContinuationFingerprint,
            incomingQualityStateFingerprint: incomingQualityStateFingerprint,
            incomingKickCorrectionDB: incomingKickCorrectionDB,
            incomingTopologyRevision: incomingTopologyRevision,
            previousGraphFingerprint: previousGraphFingerprint,
            routeRecovery: routeRecovery,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            controllerStateFingerprint: controllerStateFingerprint
        )
        guard !cancellationRequested() else { return nil }
        return AutonomousCandidateEvaluationVector(
            slot: slot,
            planFingerprint: planFingerprint,
            graphFingerprint: graphFingerprint,
            symbolic: symbolic,
            hardGates: hardGates,
            fullMix: fullMix,
            masking: masking,
            stems: stems,
            automaticMix: automaticMix,
            kickSyntax: kickSyntax,
            groovePulse: groovePulse,
            closedHat: closedHat,
            instruments: instruments,
            pulseEchoDrive: pulseEchoDrive,
            upperTiming: upperTiming,
            graph: graphEvidence,
            routeContinuation: route,
            preGraphUpperTimbreEvidence: preGraphUpperTimbreEvidence,
            postGraphUpperTimbreEvidence: upperTimbreEvidence
        )
    }

    private static func kickStepMask(_ steps: [Int]) -> UInt16? {
        var result: UInt16 = 0
        for step in steps {
            guard (0..<16).contains(step) else { return nil }
            let bit = UInt16(1) << UInt16(step)
            guard result & bit == 0 else { return nil }
            result |= bit
        }
        return result
    }

    private struct UpperTimingFingerprintTuple: Equatable {
        let role: String
        let baseOnsetStep: Int
        let offsetBitPattern: UInt64
        let expectedOnsetFrame: Int
        let appliedOnsetFrame: Int
        let requestedGateEndFrame: Int
    }

    private struct UpperTimingAppliedGateFact: Equatable {
        let role: SynthRole
        let onsetFrame: Int
        let requestedGateEndFrame: Int
        let appliedGateEndFrame: Int
    }

    @inline(never)
    private static func makeUpperTimingEvidence(
        block: RenderBlock,
        planBPM: Double,
        routeSampleRate: Double
    ) -> AutonomousUpperTimingBarEvidence {
        let renderEvidence = block.upperTimingRenderEvidence
        let scheduleUpperNotes =
            block.resolvedPerformance.performance.signatureEvent != .textureCollapse &&
            block.resolvedPerformance.performance.roles.contains {
                $0 == .motif || $0 == .response || $0 == .atmosphere ||
                    $0 == .transition
            }
        let sourceScoreNotes = scheduleUpperNotes
            ? block.synthPerformance.upperNotes : []
        let scoreNotes = Array(
            sourceScoreNotes.prefix(maximumUpperTimingEventsPerBar)
        )
        let renderEvents = Array(
            renderEvidence.events.prefix(maximumUpperTimingEventsPerBar)
        )
        let actualRenderEvidence = Array(
            block.upperNoteRenderEvidence.prefix(maximumUpperTimingEventsPerBar)
        )
        let stepFrames = Double(renderEvidence.renderedFrameCount) / 16
        let scoreTuples = sortedUpperTimingTuples(scoreNotes.map { note in
            let expectedOnsetFrame = VoiceRenderer.upperNoteStartFrame(
                note: note,
                stepFrames: stepFrames,
                frameCount: renderEvidence.renderedFrameCount
            )
            let durationFrames = VoiceRenderer.upperNoteDurationFrames(
                note: note,
                stepFrames: stepFrames
            )
            let requestedEnd = expectedOnsetFrame.addingReportingOverflow(
                durationFrames
            )
            let requestedGateEndFrame = requestedEnd.overflow
                ? Int.max : requestedEnd.partialValue
            return UpperTimingFingerprintTuple(
                role: note.role.rawValue,
                baseOnsetStep: note.onsetStep,
                offsetBitPattern: note.timingOffsetInSteps.bitPattern,
                expectedOnsetFrame: expectedOnsetFrame,
                appliedOnsetFrame: expectedOnsetFrame,
                requestedGateEndFrame: requestedGateEndFrame
            )
        })
        let renderTuples = sortedUpperTimingTuples(renderEvents.map { event in
            UpperTimingFingerprintTuple(
                role: event.role.rawValue,
                baseOnsetStep: event.baseOnsetStep,
                offsetBitPattern: event.requestedOffsetInSteps.bitPattern,
                expectedOnsetFrame: event.expectedOnsetFrame,
                appliedOnsetFrame: event.appliedOnsetFrame,
                requestedGateEndFrame: event.requestedGateEndFrame
            )
        })
        let eventGateFacts = renderEvents.map {
            UpperTimingAppliedGateFact(
                role: $0.role,
                onsetFrame: $0.appliedOnsetFrame,
                requestedGateEndFrame: $0.requestedGateEndFrame,
                appliedGateEndFrame: $0.appliedGateEndFrame
            )
        }.sorted(by: upperTimingGateFactOrder)
        let actualGateFacts = actualRenderEvidence.map {
            UpperTimingAppliedGateFact(
                role: $0.role,
                onsetFrame: $0.onsetFrame,
                requestedGateEndFrame: $0.requestedGateEndFrame,
                appliedGateEndFrame: $0.appliedGateEndFrame
            )
        }.sorted(by: upperTimingGateFactOrder)
        let scoreFingerprint = upperTimingFingerprint(scoreTuples)
        let renderFingerprint = upperTimingFingerprint(renderTuples)
        let appliedGateFingerprint = upperTimingAppliedGateFingerprint(
            eventGateFacts
        )
        let offsets = scoreNotes.map(\.timingOffsetInSteps)
        let minimumOffset = offsets.min() ?? 0
        let maximumOffset = offsets.max() ?? 0
        let activeOffsetCount = offsets.filter { $0.bitPattern != 0 }.count
        let protectedRoleActiveOffsetCount = renderEvents.filter { event in
            (event.role == .anchor || event.role == .atmosphere ||
                event.role == .transition) &&
                event.requestedOffsetInSteps.bitPattern != 0
        }.count
        let shadowOffsets = renderEvents.filter {
            $0.role == .shadow
        }.map(\.requestedOffsetInSteps)
        let responseOffsets = renderEvents.filter {
            $0.role == .response
        }.map(\.requestedOffsetInSteps)
        let shadowSignal = AutonomousUpperTimingRoleSignalEvidence(
            role: .shadow,
            evidence: renderEvidence.shadowSignal
        )
        let responseSignal = AutonomousUpperTimingRoleSignalEvidence(
            role: .response,
            evidence: renderEvidence.responseSignal
        )
        let bindingValid = renderEvidence.bar == block.bar &&
            renderEvidence.chapter == block.resolvedPerformance.interlockChapter &&
            renderEvidence.bpm == planBPM &&
            renderEvidence.sampleRate == routeSampleRate &&
            renderEvidence.renderedFrameCount == block.left.count &&
            renderEvidence.renderedFrameCount == block.right.count &&
            sourceScoreNotes.count <= maximumUpperTimingEventsPerBar &&
            renderEvidence.events.count <= maximumUpperTimingEventsPerBar &&
            block.upperNoteRenderEvidence.count <= maximumUpperTimingEventsPerBar &&
            sourceScoreNotes.count == renderEvidence.events.count &&
            renderEvidence.events.count == block.upperNoteRenderEvidence.count &&
            scoreTuples.count == renderTuples.count &&
            scoreFingerprint == renderFingerprint &&
            eventGateFacts == actualGateFacts &&
            actualGateFacts.allSatisfy {
                $0.onsetFrame >= 0 &&
                    $0.requestedGateEndFrame > $0.onsetFrame &&
                    $0.appliedGateEndFrame >= $0.onsetFrame &&
                    $0.appliedGateEndFrame <= min(
                        $0.requestedGateEndFrame,
                        renderEvidence.renderedFrameCount
                    )
            } &&
            shadowSignal.eventCount == renderEvents.filter {
                $0.role == .shadow
            }.count &&
            responseSignal.eventCount == renderEvents.filter {
                $0.role == .response
            }.count
        let finite = planBPM.isFinite && routeSampleRate.isFinite &&
            offsets.allSatisfy(\.isFinite) &&
            renderEvents.allSatisfy { event in
                event.requestedOffsetInSteps.isFinite
            } && shadowSignal.isFinite && responseSignal.isFinite
        return AutonomousUpperTimingBarEvidence(
            bar: block.bar,
            chapter: block.resolvedPerformance.interlockChapter,
            bpm: planBPM,
            sampleRate: routeSampleRate,
            renderedFrameCount: renderEvidence.renderedFrameCount,
            sourceScoreNoteCount: sourceScoreNotes.count,
            sourceRenderEventCount: renderEvidence.events.count,
            anchorEventCount: renderEvents.filter {
                $0.role == .anchor
            }.count,
            activeOffsetCount: activeOffsetCount,
            protectedRoleActiveOffsetCount: protectedRoleActiveOffsetCount,
            minimumOffsetInSteps: minimumOffset,
            maximumOffsetInSteps: maximumOffset,
            maximumRoleSpreadInSteps: maximumOffset - minimumOffset,
            shadowMinimumOffsetInSteps: shadowOffsets.min() ?? 0,
            shadowMaximumOffsetInSteps: shadowOffsets.max() ?? 0,
            responseMinimumOffsetInSteps: responseOffsets.min() ?? 0,
            responseMaximumOffsetInSteps: responseOffsets.max() ?? 0,
            scoreFingerprint: scoreFingerprint,
            renderFingerprint: renderFingerprint,
            appliedGateFingerprint: appliedGateFingerprint,
            shadowSignal: shadowSignal,
            responseSignal: responseSignal,
            bindingValid: bindingValid,
            finite: finite
        )
    }

    private static func sortedUpperTimingTuples(
        _ tuples: [UpperTimingFingerprintTuple]
    ) -> [UpperTimingFingerprintTuple] {
        tuples.sorted { lhs, rhs in
            let lhsRole = SynthRole(rawValue: lhs.role).flatMap {
                SynthRole.allCases.firstIndex(of: $0)
            } ?? Int.max
            let rhsRole = SynthRole(rawValue: rhs.role).flatMap {
                SynthRole.allCases.firstIndex(of: $0)
            } ?? Int.max
            if lhsRole != rhsRole { return lhsRole < rhsRole }
            if lhs.baseOnsetStep != rhs.baseOnsetStep {
                return lhs.baseOnsetStep < rhs.baseOnsetStep
            }
            if lhs.offsetBitPattern != rhs.offsetBitPattern {
                return lhs.offsetBitPattern < rhs.offsetBitPattern
            }
            if lhs.expectedOnsetFrame != rhs.expectedOnsetFrame {
                return lhs.expectedOnsetFrame < rhs.expectedOnsetFrame
            }
            if lhs.appliedOnsetFrame != rhs.appliedOnsetFrame {
                return lhs.appliedOnsetFrame < rhs.appliedOnsetFrame
            }
            return lhs.requestedGateEndFrame < rhs.requestedGateEndFrame
        }
    }

    private static func upperTimingGateFactOrder(
        _ lhs: UpperTimingAppliedGateFact,
        _ rhs: UpperTimingAppliedGateFact
    ) -> Bool {
        let lhsRole = SynthRole.allCases.firstIndex(of: lhs.role) ?? Int.max
        let rhsRole = SynthRole.allCases.firstIndex(of: rhs.role) ?? Int.max
        if lhsRole != rhsRole { return lhsRole < rhsRole }
        if lhs.onsetFrame != rhs.onsetFrame { return lhs.onsetFrame < rhs.onsetFrame }
        if lhs.requestedGateEndFrame != rhs.requestedGateEndFrame {
            return lhs.requestedGateEndFrame < rhs.requestedGateEndFrame
        }
        return lhs.appliedGateEndFrame < rhs.appliedGateEndFrame
    }

    @inline(never)
    private static func upperTimingFingerprint(
        _ tuples: [UpperTimingFingerprintTuple]
    ) -> String {
        var sink = StreamingFNV1a()
        sink.domain("upper-timing-tuples.typed.v1")
        sink.collection(tuples.count)
        for tuple in tuples {
            sink.aggregate("UpperTimingFingerprintTuple")
            sink.field("role"); sink.raw(tuple.role)
            sink.field("baseOnsetStep"); sink.int(tuple.baseOnsetStep)
            sink.field("offsetBitPattern"); sink.uint64(tuple.offsetBitPattern)
            sink.field("expectedOnsetFrame"); sink.int(tuple.expectedOnsetFrame)
            sink.field("appliedOnsetFrame"); sink.int(tuple.appliedOnsetFrame)
            sink.field("requestedGateEndFrame"); sink.int(tuple.requestedGateEndFrame)
        }
        return fixedWidthFingerprintHex(sink.value)
    }

    @inline(never)
    private static func upperTimingAppliedGateFingerprint(
        _ facts: [UpperTimingAppliedGateFact]
    ) -> String {
        var sink = StreamingFNV1a()
        sink.domain("upper-timing-applied-gates.typed.v1")
        sink.collection(facts.count)
        for fact in facts {
            sink.aggregate("UpperTimingAppliedGateFact")
            sink.field("role"); sink.raw(fact.role.rawValue)
            sink.field("onsetFrame"); sink.int(fact.onsetFrame)
            sink.field("requestedGateEndFrame"); sink.int(fact.requestedGateEndFrame)
            sink.field("appliedGateEndFrame"); sink.int(fact.appliedGateEndFrame)
        }
        return fixedWidthFingerprintHex(sink.value)
    }

    package var isFinite: Bool {
        symbolic.isFinite && fullMix.isFinite && masking.allSatisfy { $0.isFinite } &&
            stems.allSatisfy { $0.isFinite } &&
            automaticMix.allSatisfy { $0.isFinite } &&
            kickSyntax.allSatisfy { $0.isFinite } &&
            groovePulse.allSatisfy { $0.isFinite } &&
            closedHat.allSatisfy { $0.isFinite } &&
            instruments.allSatisfy { $0.isFinite } &&
            pulseEchoDrive.allSatisfy { $0.isFinite } &&
            upperTiming.allSatisfy { $0.isFinite } &&
            routeContinuation.isFinite &&
            preGraphUpperTimbreEvidence.candidateValuesAreFinite &&
            postGraphUpperTimbreEvidence.candidateValuesAreFinite
    }

    package var isComplete: Bool {
        guard identityAndPrimaryEvidenceAreComplete(),
              symbolicBarCoverageIsComplete(),
              automaticMixControllerTrajectoryIsComplete() else {
            return false
        }
        let expectedBars = Set(fullMix.bars.map { $0.bar })
        return sourceCountsAreComplete() &&
            maskingEvidenceIsComplete(expectedBars: expectedBars) &&
            stemEvidenceIsComplete(expectedBars: expectedBars) &&
            automaticMixEvidenceIsComplete(expectedBars: expectedBars) &&
            kickSyntaxEvidenceIsComplete(expectedBars: expectedBars) &&
            groovePulseEvidenceIsComplete(expectedBars: expectedBars) &&
            closedHatEvidenceIsComplete(expectedBars: expectedBars) &&
            instrumentEvidenceIsComplete(expectedBars: expectedBars) &&
            pulseEchoDriveEvidenceIsComplete(expectedBars: expectedBars) &&
            upperTimingEvidenceIsComplete(expectedBars: expectedBars)
    }

    @inline(never)
    private func identityAndPrimaryEvidenceAreComplete() -> Bool {
        let slotMatchesSymbolicIntent: Bool
        switch slot {
        case .primary:
            slotMatchesSymbolicIntent = !symbolic.alternate && !symbolic.conservative
        case .alternate:
            slotMatchesSymbolicIntent = symbolic.alternate && !symbolic.conservative
        case .fallback:
            slotMatchesSymbolicIntent = !symbolic.alternate && symbolic.conservative
        }
        guard schemaVersion == Self.schemaVersion,
              !planFingerprint.isEmpty, !graphFingerprint.isEmpty,
              planFingerprint == symbolic.planFingerprint,
              graphFingerprint == graph.graphFingerprint,
              slotMatchesSymbolicIntent,
              symbolic.isComplete, hardGates.isComplete, fullMix.isComplete,
              graph.isComplete, routeContinuation.isComplete,
              sourceInstrumentBarCount == instruments.count,
              instruments.count == fullMix.sourceBarCount,
              instruments.allSatisfy({ $0.isComplete }),
              sourcePulseEchoDriveBarCount == pulseEchoDrive.count,
              pulseEchoDrive.count == fullMix.sourceBarCount,
              sourceUpperTimingBarCount == upperTiming.count,
              upperTiming.count == fullMix.sourceBarCount,
              preGraphUpperTimbreEvidence.candidateEvidenceIsComplete(
                windowCount: fullMix.sourceBarCount
              ),
              postGraphUpperTimbreEvidence.candidateEvidenceIsComplete(
                windowCount: fullMix.sourceBarCount
              ),
              preGraphUpperTimbreEvidence.analyzedFrameCount ==
                postGraphUpperTimbreEvidence.analyzedFrameCount,
              fullMix.analyzedFrameCount ==
                postGraphUpperTimbreEvidence.analyzedFrameCount,
              fullMix.perceptual.fftFrameCount ==
                StreamingPerceptualEvidenceAnalyzer.fftFrameCount(
                    sampleRate: routeContinuation.sampleRate
                ),
              preGraphUpperTimbreEvidence.sampleRate == routeContinuation.sampleRate,
              postGraphUpperTimbreEvidence.sampleRate == routeContinuation.sampleRate else {
            return false
        }
        return true
    }

    @inline(never)
    private func symbolicBarCoverageIsComplete() -> Bool {
        let expectedBars = Set(fullMix.bars.map { $0.bar })
        guard symbolic.startBar <= Int.max - symbolic.declaredBarCount else {
            return false
        }
        let symbolicBars = Set(
            symbolic.startBar..<(symbolic.startBar + symbolic.declaredBarCount)
        )
        return fullMix.sourceBarCount == symbolic.declaredBarCount &&
            expectedBars == symbolicBars
    }

    @inline(never)
    private func automaticMixControllerTrajectoryIsComplete() -> Bool {
        let finalBar = symbolic.startBar + symbolic.declaredBarCount - 1
        let orderedMix = automaticMix.sorted { $0.bar < $1.bar }
        var expectedKick = routeContinuation.incomingKickCorrectionDB
        for mix in orderedMix {
            if !automaticMixBarIsComplete(mix, expectedKick: &expectedKick) {
                return false
            }
        }
        guard let finalMix = automaticMix.first(where: { $0.bar == finalBar }),
              let finalKick = finalMix.gains.first(where: {
                  $0.role == MixRole.kick.rawValue
              }),
              routeContinuation.controllerStateFingerprint ==
                AutonomousCandidateFingerprint.automaticMixController(
                    kickCorrectionDB: finalKick.gainDB
                ) else {
            return false
        }
        return true
    }

    @inline(never)
    private func automaticMixBarIsComplete(
        _ mix: AutonomousAutomaticMixEvidence,
        expectedKick: inout Double
    ) -> Bool {
        guard let actualKick = mix.gains.first(where: {
            $0.role == MixRole.kick.rawValue
        })?.gainDB,
              let stemBar = stems.first(where: { $0.bar == mix.bar }),
              let kick = stemBar.roles.first(where: {
                  $0.role == MixRole.kick.rawValue
              }),
              let foundation = stemBar.roles.first(where: {
                  $0.role == MixRole.foundation.rawValue
              }),
              let section = SectionKind(rawValue: mix.section),
              let companion = FoundationCompanion(
                rawValue: mix.foundationCompanion
              ) else {
            return false
        }
        let controllerShouldMeasure = kick.activeRMS > 0 &&
            section != .breakdown && companion != .empty &&
            foundation.activeRMS > 0.000_001 && foundation.occupancy >= 0.02
        if let measured = mix.measuredKickOverFoundationDB,
           let target = mix.targetKickOverFoundationDB {
            guard controllerShouldMeasure,
                  target == expectedKickTarget(for: companion) else {
                return false
            }
            let expectedMeasured =
                20 * log10(max(kick.activeRMS, 0.000_000_001)) - actualKick -
                20 * log10(max(foundation.activeRMS, 0.000_000_001))
            guard abs(measured - expectedMeasured) <= 1e-6 else {
                return false
            }
            let error = target - (measured + expectedKick)
            if abs(error) > AutomaticMixBalancer.deadbandDB {
                let step = min(
                    AutomaticMixBalancer.maximumStepDB,
                    max(-AutomaticMixBalancer.maximumStepDB, error * 0.5)
                )
                expectedKick = min(
                    0,
                    max(
                        AutomaticMixBalancer.minimumKickCorrectionDB,
                        expectedKick + step
                    )
                )
            }
        } else if controllerShouldMeasure {
            return false
        }
        return actualKick == expectedKick
    }

    @inline(never)
    private func expectedKickTarget(for companion: FoundationCompanion) -> Double {
        switch companion {
        case .bass: return 16.5
        case .monoRumble: return 27.5
        case .tunedTom: return 22.5
        case .empty: return 0
        }
    }

    @inline(never)
    private func sourceCountsAreComplete() -> Bool {
        sourceMaskingBarCount == masking.count &&
            sourceStemBarCount == stems.count &&
            sourceAutomaticMixBarCount == automaticMix.count &&
            sourceKickSyntaxBarCount == kickSyntax.count &&
            sourceGroovePulseBarCount == groovePulse.count &&
            sourceClosedHatBarCount == closedHat.count &&
            sourceInstrumentBarCount == instruments.count &&
            sourcePulseEchoDriveBarCount == pulseEchoDrive.count &&
            sourceUpperTimingBarCount == upperTiming.count &&
            masking.count == fullMix.sourceBarCount &&
            stems.count == fullMix.sourceBarCount &&
            automaticMix.count == fullMix.sourceBarCount &&
            kickSyntax.count == fullMix.sourceBarCount &&
            groovePulse.count == fullMix.sourceBarCount &&
            closedHat.count == fullMix.sourceBarCount &&
            instruments.count == fullMix.sourceBarCount &&
            pulseEchoDrive.count == fullMix.sourceBarCount &&
            upperTiming.count == fullMix.sourceBarCount
    }

    @inline(never)
    private func maskingEvidenceIsComplete(expectedBars: Set<Int>) -> Bool {
        Set(masking.map { $0.bar }) == expectedBars &&
            masking.allSatisfy { $0.isComplete } &&
            masking.count == fullMix.sourceBarCount
    }

    @inline(never)
    private func stemEvidenceIsComplete(expectedBars: Set<Int>) -> Bool {
        Set(stems.map { $0.bar }) == expectedBars &&
            stems.allSatisfy { $0.isComplete } &&
            stems.count == fullMix.sourceBarCount
    }

    @inline(never)
    private func automaticMixEvidenceIsComplete(expectedBars: Set<Int>) -> Bool {
        Set(automaticMix.map { $0.bar }) == expectedBars &&
            automaticMix.allSatisfy { $0.isComplete } &&
            automaticMix.count == fullMix.sourceBarCount
    }

    @inline(never)
    private func kickSyntaxEvidenceIsComplete(expectedBars: Set<Int>) -> Bool {
        guard let phraseKind = AutonomousPhraseKind(rawValue: symbolic.phraseKind),
              Set(kickSyntax.map { $0.bar }) == expectedBars,
              kickSyntax.map({ $0.bar }) == fullMix.bars.map({ $0.bar }),
              kickSyntax.map({ $0.bar }) == Array(
                symbolic.startBar..<(symbolic.startBar + symbolic.declaredBarCount)
              ),
              kickSyntax.count == fullMix.sourceBarCount else {
            return false
        }
        for index in kickSyntax.indices {
            let syntax = kickSyntax[index]
            let mix = automaticMix[index]
            let stem = stems[index]
            let pulse = groovePulse[index]
            let instrument = instruments[index]
            guard syntax.bar == mix.bar, syntax.bar == stem.bar,
                  syntax.bar == pulse.bar, syntax.bar == instrument.bar,
                  syntax.isComplete(sampleRate: routeContinuation.sampleRate),
                  let kickGainDB = mix.gains.first(where: {
                      $0.role == MixRole.kick.rawValue
                  })?.gainDB,
                  syntax.audibleGain == KickMixBalance.audibleGain * Double(
                    Float(pow(10, kickGainDB / 20))
                  ),
                  let kickStem = stem.roles.first(where: {
                      $0.role == MixRole.kick.rawValue
                  }),
                  kickStem.peak == syntax.audiblePeak,
                  kickStem.rms == syntax.audibleRMS else {
                return false
            }
            guard let role = KickSyntaxRole(rawValue: syntax.role) else {
                return false
            }
            switch role {
            case .grounded, .recovery:
                guard kickStem.peak > 0, kickStem.rms > 0,
                      kickStem.activeRMS > 0, kickStem.occupancy > 0 else {
                    return false
                }
            case .withheld:
                let stemIsSilent = kickStem.rms.bitPattern == 0 &&
                    kickStem.activeRMS.bitPattern == 0 &&
                    kickStem.onsetRMS.bitPattern == 0 &&
                    kickStem.peak.bitPattern == 0 &&
                    kickStem.crestFactor.bitPattern == 0 &&
                    kickStem.occupancy.bitPattern == 0 &&
                    kickStem.bands.allSatisfy { $0.energy.bitPattern == 0 }
                let weakPulsesAreAudible =
                    pulse.sourceScoreEventCount ==
                        KickSyntaxResolver.canonicalWeakPulseSteps.count &&
                    pulse.sourceRenderEventCount == pulse.sourceScoreEventCount &&
                    pulse.events.map(\.step) ==
                        KickSyntaxResolver.canonicalWeakPulseSteps &&
                    pulse.events.allSatisfy {
                        $0.intensity > 0 && $0.sourceRMS > 0 && $0.finite
                    }
                let motifAssignmentIsPresent = instrument.architectures.contains {
                    $0.assignments.contains { $0.use == InstrumentUse.motif.rawValue }
                }
                guard stemIsSilent, weakPulsesAreAudible,
                      motifAssignmentIsPresent else {
                    return false
                }
            }
        }
        return kickSyntaxRoleArcIsCanonical(phraseKind: phraseKind)
    }

    @inline(never)
    private func kickSyntaxRoleArcIsCanonical(
        phraseKind: AutonomousPhraseKind
    ) -> Bool {
        let roles = kickSyntax.compactMap { KickSyntaxRole(rawValue: $0.role) }
        guard roles.count == kickSyntax.count else { return false }
        if roles.allSatisfy({ $0 == .grounded }) { return true }

        let withheldIndices = roles.indices.filter { roles[$0] == .withheld }
        let recoveryIndices = roles.indices.filter { roles[$0] == .recovery }
        guard phraseKind == .energyRelease, !symbolic.conservative,
              withheldIndices.count == 2, recoveryIndices.count == 1,
              let firstWithheld = withheldIndices.first,
              let recovery = recoveryIndices.first,
              firstWithheld >= 1,
              withheldIndices[1] == firstWithheld + 1,
              recovery == firstWithheld + 2,
              roles[firstWithheld - 1] == .grounded,
              roles.indices.allSatisfy({ index in
                  index == firstWithheld || index == firstWithheld + 1 ||
                      index == recovery || roles[index] == .grounded
              }),
              Self.macroPosition(kickSyntax[recovery].bar) == 15 else {
            return false
        }
        for index in (firstWithheld - 1)...recovery {
            guard automaticMix[index].foundationCompanion ==
                FoundationCompanion.bass.rawValue else {
                return false
            }
        }
        return true
    }

    private static func macroPosition(_ bar: Int) -> Int {
        let remainder = bar % 16
        return remainder >= 0 ? remainder : remainder + 16
    }

    @inline(never)
    private func groovePulseEvidenceIsComplete(expectedBars: Set<Int>) -> Bool {
        Set(groovePulse.map { $0.bar }) == expectedBars &&
            groovePulse.allSatisfy {
                $0.isComplete(sampleRate: routeContinuation.sampleRate)
            } && groovePulse.count == fullMix.sourceBarCount
    }

    @inline(never)
    private func closedHatEvidenceIsComplete(expectedBars: Set<Int>) -> Bool {
        Set(closedHat.map { $0.bar }) == expectedBars &&
            closedHat.allSatisfy {
                $0.isComplete(sampleRate: routeContinuation.sampleRate)
            } && closedHat.count == fullMix.sourceBarCount
    }

    @inline(never)
    private func instrumentEvidenceIsComplete(expectedBars: Set<Int>) -> Bool {
        Set(instruments.map { $0.bar }) == expectedBars &&
            instruments.allSatisfy { $0.isComplete } &&
            instruments.count == fullMix.sourceBarCount
    }

    @inline(never)
    private func pulseEchoDriveEvidenceIsComplete(
        expectedBars: Set<Int>
    ) -> Bool {
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: symbolic.phraseKind
        ),
              Set(pulseEchoDrive.map { $0.bar }) == expectedBars,
              pulseEchoDrive.map({ $0.bar }) == fullMix.bars.map({ $0.bar }),
              pulseEchoDrive.count == fullMix.sourceBarCount else {
            return false
        }
        for (pulse, instrument) in zip(pulseEchoDrive, instruments) {
            guard pulse.isComplete(
                sampleRate: routeContinuation.sampleRate,
                phraseKind: phraseKind,
                conservative: symbolic.conservative,
                instruments: instrument
            ) else {
                return false
            }
        }
        return true
    }

    @inline(never)
    private func upperTimingEvidenceIsComplete(expectedBars: Set<Int>) -> Bool {
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: symbolic.phraseKind
        ), Set(upperTiming.map { $0.bar }) == expectedBars,
           upperTiming.map({ $0.bar }) == fullMix.bars.map({ $0.bar }),
           upperTiming.count == fullMix.sourceBarCount else {
            return false
        }
        for (timing, pulse) in zip(upperTiming, pulseEchoDrive) {
            guard timing.bar == pulse.bar,
                  timing.chapter == pulse.interlockChapter,
                  timing.bpm == pulse.bpm,
                  timing.renderedFrameCount == pulse.renderedFrameCount,
                  timing.isComplete(
                      routeSampleRate: routeContinuation.sampleRate,
                      phraseKind: phraseKind,
                      conservative: symbolic.conservative
                  ) else {
                return false
            }
        }
        return true
    }

    /// The one selector projection shared by live preparation and transaction
    /// replay validation. It deliberately retains the shipping playback gate
    /// rather than promoting the larger uncalibrated evidence vector.
    package var selectionEvidence: AutonomousCandidateEvidence {
        AutonomousCandidateEvidence(
            symbolicValid: symbolic.interestValid,
            safetyValid: playbackHardGatesPassed,
            interesting: hardGates.audioSafetyValid,
            combinedScore: symbolic.interestScore * 0.82 +
                fullMix.movementScore * 0.18
        )
    }

    package var hardGatesPassed: Bool {
        let signalSafetyValid = fullMix.signalSafetyValid
        return hardGatesPassedForTransactionValidation(
            prevalidatedVectorIsComplete: isComplete,
            prevalidatedVectorIsFinite: isFinite,
            prevalidatedSignalSafetyValid: signalSafetyValid
        )
    }

    @inline(never)
    package func hardGatesPassedForTransactionValidation(
        prevalidatedVectorIsComplete: Bool,
        prevalidatedVectorIsFinite: Bool,
        prevalidatedSignalSafetyValid: Bool
    ) -> Bool {
        prevalidatedVectorIsComplete && prevalidatedVectorIsFinite &&
            hardGates.passed && symbolic.interestValid &&
            graph.validationValid && prevalidatedSignalSafetyValid &&
            postGraphUpperTimbreEvidence.finite &&
            postGraphUpperTimbreEvidence.candidateValuesAreFinite
    }

    /// The current shipping playback gate, kept separate from completeness of
    /// the larger descriptive vector. New evidence can block future calibrated
    /// acceptance without silently changing uncalibrated playback behavior.
    package var playbackHardGatesPassed: Bool {
        hardGates.passed && hardGateEvidenceIsConsistent
    }

    private var hardGateEvidenceIsConsistent: Bool {
        symbolic.interestValid && graph.validationValid &&
            fullMix.signalSafetyValid && postGraphUpperTimbreEvidence.finite &&
            postGraphUpperTimbreEvidence.candidateValuesAreFinite
    }

    /// Validity of the bounded record itself, independent of whether the
    /// represented candidate supplied complete/finite evidence or passed.
    package var recordIsStructurallyValid: Bool {
        let signalSafetyValid = fullMix.signalSafetyValid
        return recordIsStructurallyValid(
            prevalidatedHardGateSummaryIsCanonical:
                hardGateSummaryIsCanonicalForTransactionValidation(
                    prevalidatedSignalSafetyValid: signalSafetyValid
                )
        )
    }

    @inline(never)
    package func recordIsStructurallyValid(
        prevalidatedHardGateSummaryIsCanonical: Bool
    ) -> Bool {
        recordIdentityIsValid() && recordCountsAreBounded() &&
            recordCollectionsAreBounded() &&
            prevalidatedHardGateSummaryIsCanonical &&
            routeContinuation.isComplete
    }

    @inline(never)
    private func recordIdentityIsValid() -> Bool {
        schemaVersion == Self.schemaVersion &&
            !planFingerprint.isEmpty && !graphFingerprint.isEmpty &&
            planFingerprint == symbolic.planFingerprint &&
            graphFingerprint == graph.graphFingerprint
    }

    @inline(never)
    private func recordCountsAreBounded() -> Bool {
        sourceRecordCountsAreBounded() && retainedRecordCountsAreBounded() &&
            graphRecordCountsAreBounded() && upperTimbreRecordCountsAreBounded()
    }

    @inline(never)
    private func sourceRecordCountsAreBounded() -> Bool {
        fullMix.bars.count <= Self.maximumBarCount &&
            fullMix.sourceEvidenceBarCount >= fullMix.bars.count &&
            sourceMaskingBarCount >= masking.count &&
            sourceStemBarCount >= stems.count &&
            sourceAutomaticMixBarCount >= automaticMix.count &&
            sourceKickSyntaxBarCount >= kickSyntax.count &&
            sourceKickSyntaxBarCount <= Self.maximumBarCount &&
            sourceGroovePulseBarCount >= groovePulse.count &&
            sourceClosedHatBarCount >= closedHat.count &&
            sourceInstrumentBarCount >= instruments.count &&
            sourcePulseEchoDriveBarCount >= pulseEchoDrive.count &&
            sourceUpperTimingBarCount >= upperTiming.count
    }

    @inline(never)
    private func graphRecordCountsAreBounded() -> Bool {
        graph.violations.count <= AutonomousGraphEvidence.maximumViolationCount &&
            graph.sourceViolationCount >= graph.violations.count
    }

    @inline(never)
    private func upperTimbreRecordCountsAreBounded() -> Bool {
        preGraphUpperTimbreEvidence.velocityExpression.count <=
            UpperTimbreEvidenceAnalyzer.maximumVelocityExpressionEvents &&
            postGraphUpperTimbreEvidence.velocityExpression.count <=
                UpperTimbreEvidenceAnalyzer.maximumVelocityExpressionEvents &&
            preGraphUpperTimbreEvidence.schemaVersion ==
                UpperTimbreEvidenceAnalyzer.schemaVersion &&
            postGraphUpperTimbreEvidence.schemaVersion ==
                UpperTimbreEvidenceAnalyzer.schemaVersion &&
            preGraphUpperTimbreEvidence.analyzedFrameCount ==
                postGraphUpperTimbreEvidence.analyzedFrameCount &&
            upperTimbreRateMatchesRoute(preGraphUpperTimbreEvidence) &&
            upperTimbreRateMatchesRoute(postGraphUpperTimbreEvidence)
    }

    @inline(never)
    private func retainedRecordCountsAreBounded() -> Bool {
        masking.count <= Self.maximumBarCount &&
            stems.count <= Self.maximumBarCount &&
            automaticMix.count <= Self.maximumBarCount &&
            kickSyntax.count <= Self.maximumBarCount &&
            groovePulse.count <= Self.maximumBarCount &&
            closedHat.count <= Self.maximumBarCount &&
            instruments.count <= Self.maximumBarCount &&
            pulseEchoDrive.count <= Self.maximumBarCount &&
            upperTiming.count <= Self.maximumBarCount
    }

    @inline(never)
    private func upperTimbreRateMatchesRoute(
        _ evidence: UpperTimbreEvidence
    ) -> Bool {
        return evidence.sampleRate.isFinite &&
            evidence.sampleRate >=
                QualityQualificationContract.minimumSupportedSampleRate &&
            evidence.sampleRate <=
                QualityQualificationContract.maximumSupportedSampleRate &&
            evidence.sampleRate == routeContinuation.sampleRate
    }

    @inline(never)
    private func recordCollectionsAreBounded() -> Bool {
        maskingRecordsAreBounded() && stemRecordsAreBounded() &&
            automaticMixRecordsAreBounded() && kickSyntaxRecordsAreBounded() &&
            groovePulseRecordsAreBounded() &&
            closedHatRecordsAreBounded() && instrumentRecordsAreBounded() &&
            pulseEchoDriveRecordsAreBounded() && upperTimingRecordsAreBounded()
    }

    @inline(never)
    private func maskingRecordsAreBounded() -> Bool {
        for bar in masking where
            bar.observations.count > Self.maximumMaskingObservationsPerBar {
            return false
        }
        return true
    }

    @inline(never)
    private func stemRecordsAreBounded() -> Bool {
        for bar in stems {
            guard bar.roles.count <= Self.maximumStemRolesPerBar else {
                return false
            }
            for role in bar.roles where role.bands.count > MixBand.allCases.count {
                return false
            }
        }
        return true
    }

    @inline(never)
    private func automaticMixRecordsAreBounded() -> Bool {
        for bar in automaticMix where
            bar.gains.count > Self.maximumStemRolesPerBar {
            return false
        }
        return true
    }

    @inline(never)
    private func kickSyntaxRecordsAreBounded() -> Bool {
        kickSyntax.allSatisfy {
            (0...16).contains($0.scoreKickEventCount) &&
                (0...16).contains($0.renderedKickEventCount) &&
                $0.renderedFrameCount >= 0 &&
                $0.detectorNonzeroSampleCount >= 0 &&
                $0.detectorNonzeroSampleCount <= $0.renderedFrameCount &&
                $0.audibleNonzeroSampleCount >= 0 &&
                $0.audibleNonzeroSampleCount <= $0.renderedFrameCount
        }
    }

    @inline(never)
    private func groovePulseRecordsAreBounded() -> Bool {
        for bar in groovePulse where
            bar.events.count > Self.maximumGroovePulseEventsPerBar {
            return false
        }
        return true
    }

    @inline(never)
    private func closedHatRecordsAreBounded() -> Bool {
        for bar in closedHat where
            bar.events.count > Self.maximumClosedHatEventsPerBar {
            return false
        }
        return true
    }

    @inline(never)
    private func instrumentRecordsAreBounded() -> Bool {
        for bar in instruments {
            guard bar.architectures.count <= Self.maximumInstrumentArchitecturesPerBar else {
                return false
            }
            for architecture in bar.architectures where
                architecture.assignments.count >
                    Self.maximumInstrumentAssignmentsPerArchitecture {
                return false
            }
        }
        guard instruments.map({ $0.bar }) == fullMix.bars.map({ $0.bar }) else {
            return false
        }
        return true
    }

    @inline(never)
    private func pulseEchoDriveRecordsAreBounded() -> Bool {
        pulseEchoDrive.map({ $0.bar }) == fullMix.bars.map({ $0.bar })
    }

    @inline(never)
    private func upperTimingRecordsAreBounded() -> Bool {
        upperTiming.map({ $0.bar }) == fullMix.bars.map({ $0.bar }) &&
            upperTiming.allSatisfy {
                $0.sourceScoreNoteCount >= 0 &&
                    $0.sourceScoreNoteCount <= Self.maximumUpperTimingEventsPerBar &&
                    $0.sourceRenderEventCount >= 0 &&
                    $0.sourceRenderEventCount <= Self.maximumUpperTimingEventsPerBar &&
                    $0.anchorEventCount >= 0 &&
                    $0.anchorEventCount <= Self.maximumUpperTimingEventsPerBar &&
                    $0.activeOffsetCount >= 0 &&
                    $0.activeOffsetCount <= Self.maximumUpperTimingEventsPerBar &&
                    $0.protectedRoleActiveOffsetCount >= 0 &&
                    $0.protectedRoleActiveOffsetCount <=
                        Self.maximumUpperTimingEventsPerBar &&
                    $0.shadowSignal.eventCount >= 0 &&
                    $0.shadowSignal.eventCount <= Self.maximumUpperTimingEventsPerBar &&
                    $0.responseSignal.eventCount >= 0 &&
                    $0.responseSignal.eventCount <= Self.maximumUpperTimingEventsPerBar
            }
    }

    @inline(never)
    package func hardGateSummaryIsCanonicalForTransactionValidation(
        prevalidatedSignalSafetyValid: Bool
    ) -> Bool {
        hardGates.symbolicValid == symbolic.interestValid &&
            hardGates.graphValid == graph.validationValid &&
            hardGates.audioSafetyValid == prevalidatedSignalSafetyValid &&
            hardGates.fullMixFinite == fullMix.isFinite &&
            hardGates.upperTimbreFinite == postGraphUpperTimbreEvidence.finite &&
            hardGates.blocksPresent == (fullMix.sourceBarCount > 0) &&
            hardGates.blockChannelsAligned &&
            hardGates.allSamplesFinite == fullMix.isFinite &&
            hardGates.completeInputs == symbolic.boundsValid &&
            preGraphUpperTimbreEvidence.candidateSignalDomainsAreValid &&
            postGraphUpperTimbreEvidence.candidateSignalDomainsAreValid
    }

    package var playbackGateUpperTimbreEvidence: UpperTimbreEvidence {
        postGraphUpperTimbreEvidence
    }

    package func deterministicJSON() throws -> Data {
        try AutonomousCandidateCanonicalJSON.data(self)
    }

    package var fingerprint: String {
        AutonomousCandidateCanonicalJSON.fingerprint(self)
    }
}

package struct AutonomousCandidateAttempt: Codable, Equatable, Sendable {
    package static let schemaVersion = 1
    package static let maximumReasonCodeCount = 32

    package let schemaVersion: Int
    package let kind: AutonomousCandidateAttemptKind
    package let forceSafeGraph: Bool
    package let forceHomeUpperTimbre: Bool
    package let sourceReasonCodeCount: Int
    package let reasonCodes: [QualityReasonCode]
    package let slot: AutonomousCandidateSlot
    package let vector: AutonomousCandidateEvaluationVector

    package init(
        kind: AutonomousCandidateAttemptKind,
        forceSafeGraph: Bool = false,
        forceHomeUpperTimbre: Bool = false,
        reasonCodes: [QualityReasonCode] = [],
        vector: AutonomousCandidateEvaluationVector
    ) {
        schemaVersion = Self.schemaVersion
        self.kind = kind
        self.forceSafeGraph = forceSafeGraph
        self.forceHomeUpperTimbre = forceHomeUpperTimbre
        let normalizedReasons = Array(Set(reasonCodes)).sorted {
            $0.rawValue < $1.rawValue
        }
        sourceReasonCodeCount = normalizedReasons.count
        self.reasonCodes = Array(normalizedReasons.prefix(Self.maximumReasonCodeCount))
        slot = vector.slot
        self.vector = vector
    }

    /// Structural provenance remains valid when the represented candidate was
    /// rejected for missing/non-finite evidence or failed a hard gate.
    package var isStructurallyComplete: Bool {
        let recordIsStructurallyValid = vector.recordIsStructurallyValid
        guard recordIsStructurallyValid else {
            return isStructurallyComplete(
                prevalidatedRecordIsStructurallyValid: false,
                prevalidatedVectorIsComplete: false,
                prevalidatedVectorIsFinite: false,
                prevalidatedHardGatesPassed: false
            )
        }
        let vectorIsComplete = vector.isComplete
        let vectorIsFinite = vector.isFinite
        let signalSafetyValid = vector.fullMix.signalSafetyValid
        return isStructurallyComplete(
            prevalidatedRecordIsStructurallyValid:
                recordIsStructurallyValid,
            prevalidatedVectorIsComplete: vectorIsComplete,
            prevalidatedVectorIsFinite: vectorIsFinite,
            prevalidatedHardGatesPassed:
                vector.hardGatesPassedForTransactionValidation(
                    prevalidatedVectorIsComplete: vectorIsComplete,
                    prevalidatedVectorIsFinite: vectorIsFinite,
                    prevalidatedSignalSafetyValid: signalSafetyValid
                )
        )
    }

    @inline(never)
    package func isStructurallyComplete(
        prevalidatedRecordIsStructurallyValid: Bool,
        prevalidatedVectorIsComplete: Bool,
        prevalidatedVectorIsFinite: Bool,
        prevalidatedHardGatesPassed: Bool
    ) -> Bool {
        let missingReason = reasonCodes.contains(.evidenceMissingV1)
        let nonFiniteReason = reasonCodes.contains(.evidenceNonFiniteV1)
        let hardGateReason = reasonCodes.contains(.hardGateFailedV1)
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: vector.symbolic.phraseKind
        ) else {
            return false
        }
        let pulseEchoEligibilityMatchesAttempt = zip(
            vector.pulseEchoDrive,
            vector.instruments
        ).allSatisfy { pulse, instruments in
            !pulse.bindingValid || pulse.driveEligible == (
                pulse.normalDriveEligibility(
                    phraseKind: phraseKind,
                    conservative: vector.symbolic.conservative,
                    instruments: instruments
                ) && !forceHomeUpperTimbre
            )
        }
        let forceHomeTimingIsNeutral = !forceHomeUpperTimbre ||
            vector.upperTiming.allSatisfy { $0.activeOffsetCount == 0 }
        let upperTimingEligibilityMatchesAttempt = vector.upperTiming.allSatisfy {
            !$0.bindingValid || ($0.activeOffsetCount > 0) == (
                $0.normalTimingEligibility(
                    phraseKind: phraseKind,
                    conservative: vector.symbolic.conservative
                ) && !forceHomeUpperTimbre
            )
        }
        guard schemaVersion == Self.schemaVersion,
              slot == vector.slot,
              prevalidatedRecordIsStructurallyValid,
              vector.pulseEchoDrive.count == vector.instruments.count,
              pulseEchoEligibilityMatchesAttempt,
              forceHomeTimingIsNeutral,
              upperTimingEligibilityMatchesAttempt,
              sourceReasonCodeCount == reasonCodes.count,
              sourceReasonCodeCount <= Self.maximumReasonCodeCount else {
            return false
        }
        for (index, reason) in reasonCodes.enumerated() {
            switch reason {
            case .evidenceMissingV1, .evidenceNonFiniteV1, .hardGateFailedV1:
                break
            default:
                return false
            }
            guard !reason.rawValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty else {
                return false
            }
            if index > 0,
               reasonCodes[index - 1].rawValue >= reason.rawValue {
                return false
            }
        }
        let safeGraphExpected = kind == .initialRender && vector.slot == .fallback
        let safeGraphIsMutationFree = !safeGraphExpected ||
            (vector.graph.mutationKind == nil && vector.graph.mutatedNodeCount == 0)
        return forceSafeGraph == safeGraphExpected &&
            safeGraphIsMutationFree &&
            missingReason == !prevalidatedVectorIsComplete &&
            nonFiniteReason == !prevalidatedVectorIsFinite &&
            hardGateReason == !prevalidatedHardGatesPassed
    }

    package var isComplete: Bool { isStructurallyComplete }
    package var evidenceComplete: Bool { vector.isComplete && vector.isFinite }

    package func deterministicJSON() throws -> Data {
        try AutonomousCandidateCanonicalJSON.data(self)
    }

    package var fingerprint: String {
        AutonomousCandidateCanonicalJSON.fingerprint(self)
    }
}

package struct AutonomousCandidatePlanFingerprints: Codable, Equatable, Sendable {
    package let primary: String
    package let alternate: String
    package let fallback: String

    package init(primary: String, alternate: String, fallback: String) {
        self.primary = primary
        self.alternate = alternate
        self.fallback = fallback
    }

    package static func make(
        candidates: AutonomousPhraseCandidates
    ) -> AutonomousCandidatePlanFingerprints {
        AutonomousCandidatePlanFingerprints(
            primary: AutonomousCandidateFingerprint.plan(candidates.primary),
            alternate: AutonomousCandidateFingerprint.plan(candidates.alternate),
            fallback: AutonomousCandidateFingerprint.plan(candidates.fallback)
        )
    }

    package subscript(slot: AutonomousCandidateSlot) -> String {
        switch slot {
        case .primary: primary
        case .alternate: alternate
        case .fallback: fallback
        }
    }

    package var isComplete: Bool {
        !primary.isEmpty && !alternate.isEmpty && !fallback.isEmpty &&
            Set([primary, alternate, fallback]).count == 3
    }
}

package struct AutonomousCandidateEvaluationTransaction: Codable, Equatable, Sendable {
    package static let schemaVersion = 1
    package static let maximumCandidateAttempts =
        QualityQualificationContract.maximumDistinctCandidates
    package static let maximumCorrectionAttempts =
        QualityQualificationContract.maximumCorrectionRenders
    package static let maximumAttemptCount =
        QualityQualificationContract.maximumRenderPasses

    package let schemaVersion: Int
    package let engineVersion: String
    package let policyVersion: String
    package let evaluatorVersion: String
    package let planFingerprints: AutonomousCandidatePlanFingerprints
    package let sourceAttemptCount: Int
    package let attempts: [AutonomousCandidateAttempt]
    package let selectedAttemptIndex: Int?
    package let selectedSlot: AutonomousCandidateSlot?
    package let comparison: AutonomousCandidateComparison
    package let correctionCount: Int
    package let boundsValid: Bool

    package init(
        engineVersion: String,
        policyVersion: String,
        evaluatorVersion: String,
        planFingerprints: AutonomousCandidatePlanFingerprints,
        attempts sourceAttempts: [AutonomousCandidateAttempt],
        selectedAttemptIndex sourceSelectedAttemptIndex: Int?,
        selectedSlot: AutonomousCandidateSlot?,
        comparison: AutonomousCandidateComparison,
        correctionCount sourceCorrectionCount: Int
    ) {
        schemaVersion = Self.schemaVersion
        self.engineVersion = engineVersion
        self.policyVersion = policyVersion
        self.evaluatorVersion = evaluatorVersion
        self.planFingerprints = planFingerprints
        sourceAttemptCount = sourceAttempts.count

        var retained: [(sourceIndex: Int, attempt: AutonomousCandidateAttempt)] = []
        var candidateSlots = Set<AutonomousCandidateSlot>()
        var retainedCorrection = false
        var sourceCandidateCount = 0
        var sourceCorrectionAttemptCount = 0
        var duplicateCandidateSlot = false
        for (sourceIndex, attempt) in sourceAttempts.enumerated() {
            switch attempt.kind {
            case .initialRender:
                sourceCandidateCount += 1
                if candidateSlots.contains(attempt.vector.slot) {
                    duplicateCandidateSlot = true
                } else if candidateSlots.count < Self.maximumCandidateAttempts {
                    candidateSlots.insert(attempt.vector.slot)
                    retained.append((sourceIndex, attempt))
                }
            case .correctionRender:
                sourceCorrectionAttemptCount += 1
                if !retainedCorrection {
                    retainedCorrection = true
                    retained.append((sourceIndex, attempt))
                }
            }
        }
        retained.sort { $0.sourceIndex < $1.sourceIndex }
        attempts = retained.map { $0.attempt }
        if let sourceSelectedAttemptIndex,
           let boundedIndex = retained.firstIndex(where: {
               $0.sourceIndex == sourceSelectedAttemptIndex
           }) {
            selectedAttemptIndex = boundedIndex
        } else {
            selectedAttemptIndex = nil
        }
        self.selectedSlot = selectedSlot
        self.comparison = comparison
        correctionCount = min(Self.maximumCorrectionAttempts, max(0, sourceCorrectionCount))
        boundsValid = sourceAttempts.count <= Self.maximumAttemptCount &&
            sourceCandidateCount <= Self.maximumCandidateAttempts &&
            sourceCorrectionAttemptCount <= Self.maximumCorrectionAttempts &&
            !duplicateCandidateSlot &&
            sourceCorrectionCount == sourceCorrectionAttemptCount
    }

    package var isComplete: Bool {
        AutonomousCandidateEvaluationTransactionValidator(self).validate()
    }

    package func deterministicJSON() throws -> Data {
        try AutonomousCandidateCanonicalJSON.data(self)
    }

    package var fingerprint: String {
        AutonomousCandidateCanonicalJSON.fingerprint(self)
    }
}

/// Transaction validation deliberately uses a reference owner plus small attempt
/// indices. Candidate vectors contain many fixed-width evidence records; copying
/// them into tuple locals made the prior monolithic getter exceed the 512 KiB
/// cooperative preparation-thread stack before any audio could be committed.
private final class AutonomousCandidateEvaluationTransactionValidator {
    private struct PrevalidatedAttemptRecord {
        let recordIsStructurallyValid: Bool
        let vectorIsComplete: Bool
        let vectorIsFinite: Bool
        let hardGatesPassed: Bool
    }

    private let transaction: AutonomousCandidateEvaluationTransaction
    private var prevalidatedAttemptRecords: [PrevalidatedAttemptRecord] = []
    private var initialIndices: [Int] = []
    private var correctionIndices: [Int] = []
    private var primaryInitialIndex: Int?
    private var alternateInitialIndex: Int?
    private var fallbackInitialIndex: Int?
    private var initialForceHomeUpperTimbre: Bool?
    private var usesUncalibratedEvaluator = false

    init(_ transaction: AutonomousCandidateEvaluationTransaction) {
        self.transaction = transaction
    }

    @inline(never)
    func validate() -> Bool {
        validateHeader() &&
            prevalidateAttemptRecords() &&
            validateAttemptLayout() &&
            validateSharedInputs() &&
            validateKnownEvaluatorHistory() &&
            validateCorrectionHistory() &&
            validateFallbackHistory() &&
            validateSelectionReplay()
    }

    /// Evaluate the large vector and full-mix gates directly from the
    /// reference-owned transaction validator. Passing only four booleans into
    /// attempt layout avoids nesting full-mix signal validation beneath the
    /// attempt and vector structural getter frames on cooperative threads.
    @inline(never)
    private func prevalidateAttemptRecords() -> Bool {
        prevalidatedAttemptRecords.reserveCapacity(
            AutonomousCandidateEvaluationTransaction.maximumAttemptCount
        )
        for index in transaction.attempts.indices {
            let signalSafetyValid =
                transaction.attempts[index].vector.fullMix.signalSafetyValid
            let hardGateSummaryIsCanonical = transaction.attempts[index]
                .vector.hardGateSummaryIsCanonicalForTransactionValidation(
                    prevalidatedSignalSafetyValid: signalSafetyValid
                )
            let recordIsStructurallyValid = transaction.attempts[index]
                .vector.recordIsStructurallyValid(
                    prevalidatedHardGateSummaryIsCanonical:
                        hardGateSummaryIsCanonical
                )
            guard recordIsStructurallyValid else { return false }
            let vectorIsComplete =
                transaction.attempts[index].vector.isComplete
            let vectorIsFinite = transaction.attempts[index].vector.isFinite
            prevalidatedAttemptRecords.append(PrevalidatedAttemptRecord(
                recordIsStructurallyValid: true,
                vectorIsComplete: vectorIsComplete,
                vectorIsFinite: vectorIsFinite,
                hardGatesPassed:
                    transaction.attempts[index]
                        .vector.hardGatesPassedForTransactionValidation(
                            prevalidatedVectorIsComplete: vectorIsComplete,
                            prevalidatedVectorIsFinite: vectorIsFinite,
                            prevalidatedSignalSafetyValid: signalSafetyValid
                        )
            ))
        }
        return prevalidatedAttemptRecords.count == transaction.attempts.count
    }

    @inline(never)
    private func validateHeader() -> Bool {
        let usesUncalibratedPolicy = transaction.policyVersion ==
            QualityQualificationContract.uncalibratedPolicyVersion
        usesUncalibratedEvaluator = transaction.evaluatorVersion ==
            QualityQualificationContract.uncalibratedEvaluatorVersion
        guard transaction.schemaVersion == AutonomousCandidateEvaluationTransaction.schemaVersion,
              transaction.boundsValid,
              !transaction.engineVersion.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty,
              !transaction.policyVersion.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty,
              !transaction.evaluatorVersion.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty,
              usesUncalibratedPolicy == usesUncalibratedEvaluator,
              !usesUncalibratedEvaluator || transaction.comparison == .unavailable,
              transaction.planFingerprints.isComplete,
              !transaction.attempts.isEmpty,
              transaction.attempts.count <=
                AutonomousCandidateEvaluationTransaction.maximumAttemptCount,
              transaction.sourceAttemptCount == transaction.attempts.count,
              transaction.correctionCount >= 0,
              transaction.correctionCount <=
                AutonomousCandidateEvaluationTransaction.maximumCorrectionAttempts,
              let selectedAttemptIndex = transaction.selectedAttemptIndex,
              transaction.attempts.indices.contains(selectedAttemptIndex),
              let selectedSlot = transaction.selectedSlot else {
            return false
        }
        return transaction.attempts[selectedAttemptIndex].slot == selectedSlot
    }

    @inline(never)
    private func validateAttemptLayout() -> Bool {
        initialIndices.reserveCapacity(
            AutonomousCandidateEvaluationTransaction.maximumCandidateAttempts
        )
        correctionIndices.reserveCapacity(
            AutonomousCandidateEvaluationTransaction.maximumCorrectionAttempts
        )
        var seenInitialSlots = Set<AutonomousCandidateSlot>()
        var previousInitialRank = -1

        for index in transaction.attempts.indices {
            guard prevalidatedAttemptRecords.indices.contains(index),
                  transaction.attempts[index].isStructurallyComplete(
                    prevalidatedRecordIsStructurallyValid:
                        prevalidatedAttemptRecords[index]
                            .recordIsStructurallyValid,
                    prevalidatedVectorIsComplete:
                        prevalidatedAttemptRecords[index].vectorIsComplete,
                    prevalidatedVectorIsFinite:
                        prevalidatedAttemptRecords[index].vectorIsFinite,
                    prevalidatedHardGatesPassed:
                        prevalidatedAttemptRecords[index].hardGatesPassed
                  ),
                  transaction.attempts[index].vector.planFingerprint ==
                    transaction.planFingerprints[transaction.attempts[index].slot] else {
                return false
            }
            switch transaction.attempts[index].kind {
            case .initialRender:
                let slot = transaction.attempts[index].slot
                guard !seenInitialSlots.contains(slot),
                      let rank = Self.rank(of: slot), rank >= previousInitialRank else {
                    return false
                }
                seenInitialSlots.insert(slot)
                previousInitialRank = rank
                if let initialForceHomeUpperTimbre {
                    guard initialForceHomeUpperTimbre ==
                        transaction.attempts[index].forceHomeUpperTimbre else {
                        return false
                    }
                } else {
                    initialForceHomeUpperTimbre =
                        transaction.attempts[index].forceHomeUpperTimbre
                }
                initialIndices.append(index)
                switch slot {
                case .primary: primaryInitialIndex = index
                case .alternate: alternateInitialIndex = index
                case .fallback: fallbackInitialIndex = index
                }
            case .correctionRender:
                correctionIndices.append(index)
            }
        }

        guard initialIndices.count <=
                AutonomousCandidateEvaluationTransaction.maximumCandidateAttempts,
              correctionIndices.count == transaction.correctionCount,
              correctionIndices.count <=
                AutonomousCandidateEvaluationTransaction.maximumCorrectionAttempts,
              initialIndices.first == primaryInitialIndex,
              primaryInitialIndex != nil else {
            return false
        }
        return initialForceHomeUpperTimbre != true || transaction.correctionCount == 0
    }

    @inline(never)
    private func validateSharedInputs() -> Bool {
        guard let firstIndex = transaction.attempts.indices.first,
              let primaryInitialIndex,
              let initialForceHomeUpperTimbre else {
            return false
        }
        for index in transaction.attempts.indices where index != firstIndex {
            guard sharedRouteInputsMatch(firstIndex, index) else { return false }
        }
        guard transaction.attempts[firstIndex].vector.routeContinuation.routeRecovery ==
                initialForceHomeUpperTimbre else {
            return false
        }
        for index in transaction.attempts.indices {
            guard transaction.attempts[index].vector.symbolic.phraseIndex ==
                    transaction.attempts[primaryInitialIndex].vector.symbolic.phraseIndex,
                  transaction.attempts[index].vector.symbolic.startBar ==
                    transaction.attempts[primaryInitialIndex].vector.symbolic.startBar else {
                return false
            }
        }
        if let alternateInitialIndex,
           transaction.attempts[alternateInitialIndex].vector.symbolic.phraseKind !=
            transaction.attempts[primaryInitialIndex].vector.symbolic.phraseKind {
            return false
        }
        if let fallbackInitialIndex,
           transaction.attempts[fallbackInitialIndex].vector.symbolic.phraseKind !=
            AutonomousPhraseKind.identityReturn.rawValue {
            return false
        }
        return true
    }

    @inline(never)
    private func validateKnownEvaluatorHistory() -> Bool {
        guard usesUncalibratedEvaluator else { return true }
        guard let primaryInitialIndex else { return false }
        let routeRecovery = transaction.attempts[primaryInitialIndex]
            .vector.routeContinuation.routeRecovery
        let primaryRepairable = !routeRecovery && isRepairable(primaryInitialIndex)
        let primaryEvidence = selectionEvidence(primaryInitialIndex)
        let needsAlternate = AutonomousCandidateSelector.needsAlternate(
            primary: primaryEvidence,
            qualityComparisonAvailable: false
        ) || primaryRepairable
        guard (alternateInitialIndex != nil) == needsAlternate else { return false }

        let alternateEvidence = alternateInitialIndex.map(selectionEvidence)
        let preCorrectionChoice = AutonomousCandidateSelector.choose(
            primary: primaryEvidence,
            alternate: alternateEvidence,
            qualityComparison: .unavailable
        )
        let preCorrectionSlot: AutonomousCandidateSlot?
        switch preCorrectionChoice {
        case .primary: preCorrectionSlot = .primary
        case .alternate: preCorrectionSlot = .alternate
        case .fallback: preCorrectionSlot = nil
        }
        let alternateRepairable = !routeRecovery &&
            (alternateInitialIndex.map(isRepairable) ?? false)
        let expectedCorrectionSlot = AutonomousCandidateCorrectionPolicy.choose(
            selectedSlot: preCorrectionSlot,
            primaryRepairable: primaryRepairable,
            alternateRepairable: alternateRepairable
        )
        let actualCorrectionSlot = correctionIndices.first.map {
            transaction.attempts[$0].slot
        }
        return actualCorrectionSlot == expectedCorrectionSlot &&
            correctionIndices.isEmpty == (expectedCorrectionSlot == nil)
    }

    @inline(never)
    private func validateCorrectionHistory() -> Bool {
        guard let correctionIndex = correctionIndices.first else { return true }
        let correctionSlot = transaction.attempts[correctionIndex].slot
        guard correctionSlot != .fallback,
              transaction.attempts[correctionIndex].forceHomeUpperTimbre,
              alternateInitialIndex != nil,
              let matchingInitialIndex = initialIndex(for: correctionSlot),
              matchingInitialIndex < correctionIndex,
              correctionMatchesInitial(correctionIndex, matchingInitialIndex) else {
            return false
        }
        var lastAuthoredInitial = -1
        for index in initialIndices
        where transaction.attempts[index].slot != .fallback {
            lastAuthoredInitial = max(lastAuthoredInitial, index)
        }
        return correctionIndex > lastAuthoredInitial
    }

    @inline(never)
    private func validateFallbackHistory() -> Bool {
        guard let fallbackInitialIndex else { return true }
        guard let selectedAttemptIndex = transaction.selectedAttemptIndex else {
            return false
        }
        return fallbackInitialIndex == transaction.attempts.index(
            before: transaction.attempts.endIndex
        ) && transaction.attempts[fallbackInitialIndex].forceSafeGraph &&
            alternateInitialIndex != nil &&
            selectedAttemptIndex == fallbackInitialIndex &&
            transaction.selectedSlot == .fallback
    }

    @inline(never)
    private func validateSelectionReplay() -> Bool {
        guard let primaryInitialIndex,
              let selectedAttemptIndex = transaction.selectedAttemptIndex,
              let selectedSlot = transaction.selectedSlot else {
            return false
        }
        var replayPrimaryIndex = primaryInitialIndex
        var replayAlternateIndex = alternateInitialIndex
        if let correctionIndex = correctionIndices.first {
            let evidence = selectionEvidence(correctionIndex)
            if evidence.symbolicValid && evidence.safetyValid {
                if transaction.attempts[correctionIndex].slot == .primary {
                    replayPrimaryIndex = correctionIndex
                } else if transaction.attempts[correctionIndex].slot == .alternate {
                    replayAlternateIndex = correctionIndex
                }
            }
        }
        guard transaction.comparison != .fallback,
              transaction.comparison == .unavailable || replayAlternateIndex != nil else {
            return false
        }
        let replayChoice = AutonomousCandidateSelector.choose(
            primary: selectionEvidence(replayPrimaryIndex),
            alternate: replayAlternateIndex.map(selectionEvidence),
            qualityComparison: transaction.comparison.qualityComparison
        )
        switch replayChoice {
        case .primary:
            return selectedSlot == .primary && selectedAttemptIndex == replayPrimaryIndex
        case .alternate:
            return selectedSlot == .alternate &&
                selectedAttemptIndex == replayAlternateIndex
        case .fallback:
            return selectedSlot == .fallback &&
                selectedAttemptIndex == fallbackInitialIndex
        }
    }

    @inline(never)
    private func sharedRouteInputsMatch(_ firstIndex: Int, _ candidateIndex: Int) -> Bool {
        let first = transaction.attempts[firstIndex].vector.routeContinuation
        let candidate = transaction.attempts[candidateIndex].vector.routeContinuation
        return candidate.sampleRate == first.sampleRate &&
            candidate.channelCount == first.channelCount &&
            candidate.routeGeneration == first.routeGeneration &&
            candidate.routeFingerprint == first.routeFingerprint &&
            candidate.incomingContinuationFingerprint ==
                first.incomingContinuationFingerprint &&
            candidate.incomingQualityStateFingerprint ==
                first.incomingQualityStateFingerprint &&
            candidate.incomingKickCorrectionDB == first.incomingKickCorrectionDB &&
            candidate.incomingTopologyRevision == first.incomingTopologyRevision &&
            candidate.previousGraphFingerprint == first.previousGraphFingerprint &&
            candidate.routeRecovery == first.routeRecovery
    }

    @inline(never)
    private func correctionMatchesInitial(
        _ correctionIndex: Int,
        _ initialIndex: Int
    ) -> Bool {
        transaction.attempts[correctionIndex].vector.symbolic ==
            transaction.attempts[initialIndex].vector.symbolic &&
            transaction.attempts[correctionIndex].vector.graph ==
            transaction.attempts[initialIndex].vector.graph &&
            transaction.attempts[correctionIndex].vector.kickSyntax ==
            transaction.attempts[initialIndex].vector.kickSyntax
    }

    @inline(never)
    private func isRepairable(_ index: Int) -> Bool {
        UncalibratedAutonomousCandidateEvaluator.requestsHomeUpperTimbreCorrection(
            for: transaction.attempts[index].vector
        )
    }

    @inline(never)
    private func selectionEvidence(_ index: Int) -> AutonomousCandidateEvidence {
        transaction.attempts[index].vector.selectionEvidence
    }

    private func initialIndex(for slot: AutonomousCandidateSlot) -> Int? {
        switch slot {
        case .primary: primaryInitialIndex
        case .alternate: alternateInitialIndex
        case .fallback: fallbackInitialIndex
        }
    }

    private static func rank(of slot: AutonomousCandidateSlot) -> Int? {
        switch slot {
        case .primary: 0
        case .alternate: 1
        case .fallback: 2
        }
    }
}

private extension AutonomousCandidateComparison {
    var qualityComparison: AutonomousQualityComparison {
        switch self {
        case .unavailable: .unavailable
        case .primary: .primary
        case .alternate: .alternate
        case .tie: .tie
        case .fallback: .unavailable
        }
    }
}

/// Separately names every continuation owner before combining them. The
/// combined value is suitable for the reduced route/continuation evidence.
package struct AutonomousCandidateContinuationFingerprint: Codable, Equatable, Sendable {
    package let renderState: String
    package let generatedDSPState: String
    package let qualityState: String
    package let topologyRevision: Int
    package let previousGraphFingerprint: String
    package let routeRecovery: Bool
    package let combined: String

    package static func make(
        renderState: RenderState,
        generatedDSPState: GeneratedDSPContinuationState,
        qualityState: QualityContinuationState,
        topologyRevision: Int,
        previousGraphFingerprint: String,
        routeRecovery: Bool
    ) -> AutonomousCandidateContinuationFingerprint {
        let render = AutonomousCandidateFingerprint.renderState(renderState)
        let graph = AutonomousCandidateFingerprint.generatedDSPState(generatedDSPState)
        let quality = AutonomousCandidateFingerprint.qualityState(qualityState)
        return assembled(
            render: render,
            graph: graph,
            quality: quality,
            topologyRevision: topologyRevision,
            previousGraphFingerprint: previousGraphFingerprint,
            routeRecovery: routeRecovery
        )
    }

    package static func make(
        renderState: RenderState,
        generatedDSPState: GeneratedDSPContinuationState,
        qualityState: QualityContinuationState,
        topologyRevision: Int,
        previousGraphFingerprint: String,
        routeRecovery: Bool,
        cancellationRequested: @Sendable () -> Bool
    ) -> AutonomousCandidateContinuationFingerprint? {
        guard let render = AutonomousCandidateFingerprint.renderState(
            renderState,
            cancellationRequested: cancellationRequested
        ), let graph = AutonomousCandidateFingerprint.generatedDSPState(
            generatedDSPState,
            cancellationRequested: cancellationRequested
        ), !cancellationRequested() else { return nil }
        let quality = AutonomousCandidateFingerprint.qualityState(qualityState)
        guard !cancellationRequested() else { return nil }
        return assembled(
            render: render,
            graph: graph,
            quality: quality,
            topologyRevision: topologyRevision,
            previousGraphFingerprint: previousGraphFingerprint,
            routeRecovery: routeRecovery
        )
    }

    private static func assembled(
        render: String,
        graph: String,
        quality: String,
        topologyRevision: Int,
        previousGraphFingerprint: String,
        routeRecovery: Bool
    ) -> AutonomousCandidateContinuationFingerprint {
        AutonomousCandidateContinuationFingerprint(
            renderState: render,
            generatedDSPState: graph,
            qualityState: quality,
            topologyRevision: topologyRevision,
            previousGraphFingerprint: previousGraphFingerprint,
            routeRecovery: routeRecovery,
            combined: AutonomousCandidateCanonicalJSON.fingerprint(
                FingerprintPayload(
                    version: "candidate-continuation.v1",
                    renderState: render,
                    generatedDSPState: graph,
                    qualityState: quality,
                    topologyRevision: topologyRevision,
                    previousGraphFingerprint: previousGraphFingerprint,
                    routeRecovery: routeRecovery
                )
            )
        )
    }

    private struct FingerprintPayload: Codable {
        let version: String
        let renderState: String
        let generatedDSPState: String
        let qualityState: String
        let topologyRevision: Int
        let previousGraphFingerprint: String
        let routeRecovery: Bool
    }
}

/// Final, post-decision identity for the exact atomic prepared phrase. It sits
/// outside the transaction so the finalized quality state can be bound without
/// creating a self-referential evidence fingerprint.
package struct AutonomousPreparedCommitProvenance: Codable, Equatable, Sendable {
    package static let schemaVersion = 1

    package let schemaVersion: Int
    package let candidateEvaluationFingerprint: String
    package let selectedSampleHash: String
    package let outgoingRenderDSPFingerprint: String
    package let outgoingQualityStateFingerprint: String
    package let fingerprint: String

    package init(
        candidateEvaluationFingerprint: String,
        selectedSampleHash: String,
        outgoingRenderDSPFingerprint: String,
        qualityState: QualityContinuationState
    ) {
        schemaVersion = Self.schemaVersion
        self.candidateEvaluationFingerprint = candidateEvaluationFingerprint
        self.selectedSampleHash = selectedSampleHash
        self.outgoingRenderDSPFingerprint = outgoingRenderDSPFingerprint
        outgoingQualityStateFingerprint =
            AutonomousCandidateFingerprint.qualityState(qualityState)
        fingerprint = Self.fingerprint(
            candidateEvaluationFingerprint: candidateEvaluationFingerprint,
            selectedSampleHash: selectedSampleHash,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            outgoingQualityStateFingerprint: outgoingQualityStateFingerprint
        )
    }

    package var isComplete: Bool {
        schemaVersion == Self.schemaVersion &&
            !candidateEvaluationFingerprint.isEmpty && !selectedSampleHash.isEmpty &&
            !outgoingRenderDSPFingerprint.isEmpty &&
            !outgoingQualityStateFingerprint.isEmpty && !fingerprint.isEmpty
    }

    package var isInternallyConsistent: Bool {
        isComplete && fingerprint == Self.fingerprint(
            candidateEvaluationFingerprint: candidateEvaluationFingerprint,
            selectedSampleHash: selectedSampleHash,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            outgoingQualityStateFingerprint: outgoingQualityStateFingerprint
        )
    }

    package func matches(
        candidateEvaluationFingerprint: String,
        selectedSampleHash: String,
        outgoingRenderDSPFingerprint: String,
        qualityState: QualityContinuationState
    ) -> Bool {
        isInternallyConsistent &&
            self.candidateEvaluationFingerprint == candidateEvaluationFingerprint &&
            self.selectedSampleHash == selectedSampleHash &&
            self.outgoingRenderDSPFingerprint == outgoingRenderDSPFingerprint &&
            outgoingQualityStateFingerprint ==
                AutonomousCandidateFingerprint.qualityState(qualityState)
    }

    private struct FingerprintPayload: Codable {
        let version: String
        let candidateEvaluationFingerprint: String
        let selectedSampleHash: String
        let outgoingRenderDSPFingerprint: String
        let outgoingQualityStateFingerprint: String
    }

    private static func fingerprint(
        candidateEvaluationFingerprint: String,
        selectedSampleHash: String,
        outgoingRenderDSPFingerprint: String,
        outgoingQualityStateFingerprint: String
    ) -> String {
        AutonomousCandidateCanonicalJSON.fingerprint(FingerprintPayload(
            version: "prepared-commit.v1",
            candidateEvaluationFingerprint: candidateEvaluationFingerprint,
            selectedSampleHash: selectedSampleHash,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            outgoingQualityStateFingerprint: outgoingQualityStateFingerprint
        ))
    }
}

/// Stable exact fingerprints for non-Codable canonical state. Stored-property
/// labels, enum cases, array shape, sorted dictionary/set keys, and exact
/// IEEE-754 bit patterns all participate.
package enum AutonomousCandidateFingerprint {
    package static func plan(_ plan: AutonomousPhrasePlan) -> String {
        AutonomousTypedFingerprint.plan(plan)
    }

    package static func graph(_ graph: DSPGraphPlan) -> String {
        AutonomousTypedFingerprint.graph(graph)
    }

    package static func renderState(_ state: RenderState) -> String {
        AutonomousTypedFingerprint.renderState(state)
    }

    package static func renderState(
        _ state: RenderState,
        cancellationRequested: @Sendable () -> Bool
    ) -> String? {
        AutonomousTypedFingerprint.renderState(
            state,
            cancellationRequested: cancellationRequested
        )
    }

    package static func generatedDSPState(_ state: GeneratedDSPContinuationState) -> String {
        AutonomousTypedFingerprint.generatedDSPState(state)
    }

    package static func generatedDSPState(
        _ state: GeneratedDSPContinuationState,
        cancellationRequested: @Sendable () -> Bool
    ) -> String? {
        AutonomousTypedFingerprint.generatedDSPState(
            state,
            cancellationRequested: cancellationRequested
        )
    }

    package static func qualityState(_ state: QualityContinuationState) -> String {
        AutonomousTypedFingerprint.qualityState(state)
    }

    package static func renderDSPContinuation(
        renderState: RenderState,
        generatedDSPState: GeneratedDSPContinuationState
    ) -> String {
        AutonomousTypedFingerprint.renderDSPContinuation(
            renderState: renderState,
            generatedDSPState: generatedDSPState
        )
    }

    package static func renderDSPContinuation(
        renderState: RenderState,
        generatedDSPState: GeneratedDSPContinuationState,
        cancellationRequested: @Sendable () -> Bool
    ) -> String? {
        AutonomousTypedFingerprint.renderDSPContinuation(
            renderState: renderState,
            generatedDSPState: generatedDSPState,
            cancellationRequested: cancellationRequested
        )
    }

    package static func route(
        sampleRate: Double,
        channelCount: Int = 2,
        generation: Int
    ) -> String {
        AutonomousTypedFingerprint.route(
            sampleRate: sampleRate,
            channelCount: channelCount,
            generation: generation
        )
    }

    package static func automaticMixController(
        kickCorrectionDB: Double
    ) -> String {
        "automatic-mix.v1." + fixedWidthFingerprintHex(
            kickCorrectionDB.bitPattern
        )
    }
}

private enum AutonomousCandidateCanonicalJSON {
    static func data<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return try encoder.encode(value)
    }

    static func fingerprint<T: Encodable>(_ value: T) -> String {
        guard let encoded = try? data(value) else { return "" }
        return fnv(encoded)
    }

    private static func fnv(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return fixedWidthFingerprintHex(hash)
    }
}

private extension UpperTimbreEvidence {
    var candidateValuesAreFinite: Bool {
        let scalarValues = [
            sampleRate, rms, crestFactor, filterContourRise, filterContourDecay,
            accentContrastDB, slideMaximumDelta, detuneMotionDepth,
            detuneMotionPeriodSeconds, highBandEnergyRatio, aliasBandEnergyRatio,
            stereoWidthRatio, monoLossDB, stereoCorrelation, maskingOverlap,
            maximumBoundaryDelta,
        ]
        guard finite else { return false }
        for value in scalarValues where !value.isFinite { return false }
        for event in velocityExpression {
            let eventValues = [
                event.velocity, event.appliedStartFrequency,
                event.spectralEnvelopeScale, event.decayScale, event.sourceRMS,
                event.attackHighBandRatio, event.tailToAttackDB,
            ]
            for value in eventValues where !value.isFinite { return false }
        }
        return true
    }

    var candidateSignalDomainsAreValid: Bool {
        let maximumFloatMagnitude = Double(Float.greatestFiniteMagnitude)
        let maximumBoundaryDelta = maximumFloatMagnitude * 2
        let maximumPeriod = sampleRate > 0
            ? Double(max(0, analyzedFrameCount)) / sampleRate : 0
        guard sampleRate.isFinite, sampleRate > 0,
              analyzedFrameCount >= 0, accentedOnsetCount >= 0,
              unaccentedOnsetCount >= 0, slideWindowCount >= 0,
              duplicateAttackCount >= 0,
              rms >= 0, rms <= maximumFloatMagnitude,
              crestFactor >= 0, crestFactor <= 1_000_000,
              filterContourRise >= 0, filterContourRise <= 1,
              filterContourDecay >= 0, filterContourDecay <= 1,
              accentContrastDB >= -60, accentContrastDB <= 60,
              slideMaximumDelta >= 0, slideMaximumDelta <= maximumBoundaryDelta,
              detuneMotionDepth >= 0, detuneMotionDepth <= 1,
              detuneMotionPeriodSeconds >= 0,
              detuneMotionPeriodSeconds <= maximumPeriod,
              highBandEnergyRatio >= 0, highBandEnergyRatio <= 1,
              aliasBandEnergyRatio >= 0, aliasBandEnergyRatio <= 1,
              stereoWidthRatio >= 0, stereoWidthRatio <= 120,
              monoLossDB >= -120, monoLossDB <= 0,
              stereoCorrelation >= -1, stereoCorrelation <= 1,
              maskingOverlap >= 0, maskingOverlap <= 1,
              self.maximumBoundaryDelta >= 0,
              self.maximumBoundaryDelta <= maximumBoundaryDelta else {
            return false
        }
        for event in velocityExpression {
            guard event.velocity >= 0, event.velocity <= 1,
                  event.appliedStartFrequency >= 0,
                  event.appliedStartFrequency <= sampleRate * 0.5,
                  event.spectralEnvelopeScale >= 0.40,
                  event.spectralEnvelopeScale <= 1.60,
                  event.decayScale >= 0.80, event.decayScale <= 1.20,
                  event.sourceRMS >= 0, event.sourceRMS <= maximumFloatMagnitude,
                  event.attackHighBandRatio >= 0, event.attackHighBandRatio <= 1,
                  event.tailToAttackDB >= -120, event.tailToAttackDB <= 120 else {
                return false
            }
        }
        return true
    }

    func candidateEvidenceIsComplete(windowCount: Int) -> Bool {
        guard windowCount > 0,
              windowCount <= AutonomousCandidateEvaluationVector.maximumBarCount else {
            return false
        }
        func boundedProduct(_ value: Int) -> Int {
            value > Int.max / windowCount ? Int.max : value * windowCount
        }
        let maximumFrames = boundedProduct(UpperTimbreEvidenceAnalyzer.maximumFrames)
        let maximumOnsets = boundedProduct(UpperTimbreEvidenceAnalyzer.maximumOnsets)
        let maximumSlides = boundedProduct(
            UpperTimbreEvidenceAnalyzer.maximumSlideWindows
        )
        let maximumDuplicates = boundedProduct(
            UpperTimbreEvidenceAnalyzer.maximumMetadataItems
        )
        guard schemaVersion == UpperTimbreEvidenceAnalyzer.schemaVersion,
              sampleRate > 0, analyzedFrameCount > 0,
              candidateSignalDomainsAreValid,
              analyzedFrameCount <= maximumFrames,
              accentedOnsetCount >= 0, accentedOnsetCount <= maximumOnsets,
              unaccentedOnsetCount >= 0, unaccentedOnsetCount <= maximumOnsets,
              slideWindowCount >= 0, slideWindowCount <= maximumSlides,
              duplicateAttackCount >= 0,
              duplicateAttackCount <= maximumDuplicates,
              velocityExpression.count <=
                UpperTimbreEvidenceAnalyzer.maximumVelocityExpressionEvents else {
            return false
        }
        for event in velocityExpression {
            guard event.complete, event.onsetFrame >= 0,
                  event.analyzedEndFrame >= event.onsetFrame,
                  event.analyzedEndFrame <= analyzedFrameCount,
                  event.analyzedFrameCount ==
                    event.analyzedEndFrame - event.onsetFrame,
                  event.velocity >= 0, event.velocity <= 1,
                  event.appliedStartFrequency > 0,
                  event.spectralEnvelopeScale >= 0.40,
                  event.spectralEnvelopeScale <= 1.60,
                  event.decayScale >= 0.80, event.decayScale <= 1.20,
                  event.sourceRMS > 0,
                  event.attackHighBandRatio >= 0,
                  event.attackHighBandRatio <= 1,
                  event.tailToAttackDB >= -120,
                  event.tailToAttackDB <= 120 else {
                return false
            }
        }
        return true
    }
}
