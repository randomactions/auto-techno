import AutoTechnoCore
import Foundation

/// One initial primary render and at most one correction render may be retained
/// by an evaluation transaction.
package enum AutonomousCandidateAttemptKind: String, Codable, CaseIterable, Sendable {
    case initialRender
    case correctionRender
}

/// Compact projection of the primary render's playback gate. It is diagnostic
/// evidence only; the calibrated evaluator owns the terminal decision.
package struct AutonomousPlaybackGateEvidence: Equatable, Sendable {
    package let symbolicValid: Bool
    package let safetyValid: Bool
    package let interesting: Bool
    package let combinedScore: Double

    package init(symbolicValid: Bool, safetyValid: Bool, interesting: Bool,
                 combinedScore: Double) {
        self.symbolicValid = symbolicValid
        self.safetyValid = safetyValid
        self.interesting = interesting
        self.combinedScore = min(1, max(0, combinedScore))
    }
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

package enum AutonomousRoleStemCompletenessFailure: String, Codable,
        Equatable, Sendable {
    case invalidRole = "invalid-role"
    case levelBounds = "level-bounds"
    case crestMismatch = "crest-mismatch"
    case silentTuple = "silent-tuple"
    case activeTuple = "active-tuple"
    case occupancyBounds = "occupancy-bounds"
    case bandCount = "band-count"
    case bandValue = "band-value"
    case bandEnergyBounds = "band-energy-bounds"
    case bandIdentity = "band-identity"
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
        completenessFailures.isEmpty
    }

    package var completenessFailures: [AutonomousRoleStemCompletenessFailure] {
        let maximumFloatMagnitude = Double(Float.greatestFiniteMagnitude)
        let expectedCrest = peak == 0 ? 0 : peak / max(rms, 0.000_000_001)
        let silentTupleIsConsistent = peak != 0 ||
            (rms == 0 && activeRMS == 0 && onsetRMS == 0 &&
                crestFactor == 0 && occupancy == 0 &&
                bands.allSatisfy { $0.energy == 0 })
        let activeTupleIsConsistent = peak == 0 ||
            (rms > 0 && activeRMS > 0 && occupancy > 0 &&
                bands.contains { $0.energy > 0 })
        var failures: [AutonomousRoleStemCompletenessFailure] = []
        if !MixRole.allCases.map({ $0.rawValue }).contains(role) {
            failures.append(.invalidRole)
        }
        if !(rms >= 0 && rms <= peak && activeRMS >= rms &&
                activeRMS <= peak && onsetRMS >= 0 && onsetRMS <= peak &&
                peak >= 0 && peak <= maximumFloatMagnitude) {
            failures.append(.levelBounds)
        }
        if abs(crestFactor - expectedCrest) > 1e-9 {
            failures.append(.crestMismatch)
        }
        if !silentTupleIsConsistent { failures.append(.silentTuple) }
        if !activeTupleIsConsistent { failures.append(.activeTuple) }
        if !(0...1).contains(occupancy) {
            failures.append(.occupancyBounds)
        }
        if sourceBandCount != bands.count ||
                bands.count != MixBand.allCases.count {
            failures.append(.bandCount)
        }
        if !bands.allSatisfy({ $0.isComplete }) {
            failures.append(.bandValue)
        }
        if !bands.allSatisfy({ $0.energy <= 4 * peak * peak + 1e-12 }) {
            failures.append(.bandEnergyBounds)
        }
        if Set(bands.map({ $0.band })) !=
                Set(MixBand.allCases.map({ $0.rawValue })) {
            failures.append(.bandIdentity)
        }
        return failures
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
    package let sourceKickRMS: Double?
    package let sourceKickActiveRMS: Double?

    package init(
        bar: Int,
        section: String,
        foundationCompanion: String,
        gains: [AutonomousRoleGainEvidence],
        measuredKickOverFoundationDB: Double?,
        targetKickOverFoundationDB: Double?,
        sourceKickRMS: Double? = nil,
        sourceKickActiveRMS: Double? = nil
    ) {
        self.bar = bar
        self.section = section
        self.foundationCompanion = foundationCompanion
        sourceGainCount = gains.count
        self.gains = Array(gains.prefix(MixRole.allCases.count))
        self.measuredKickOverFoundationDB = measuredKickOverFoundationDB
        self.targetKickOverFoundationDB = targetKickOverFoundationDB
        self.sourceKickRMS = sourceKickRMS
        self.sourceKickActiveRMS = sourceKickActiveRMS
    }

    package var isFinite: Bool {
        gains.allSatisfy { $0.isFinite } &&
            (measuredKickOverFoundationDB?.isFinite ?? true) &&
            (targetKickOverFoundationDB?.isFinite ?? true) &&
            (sourceKickRMS?.isFinite ?? true) &&
            (sourceKickActiveRMS?.isFinite ?? true)
    }

    package var isComplete: Bool {
        SectionKind(rawValue: section) != nil &&
            FoundationCompanion(rawValue: foundationCompanion) != nil &&
            sourceGainCount == gains.count && gains.count == MixRole.allCases.count &&
            gains.allSatisfy { $0.isComplete } &&
            Set(gains.map { $0.role }) == Set(MixRole.allCases.map { $0.rawValue }) &&
            (
                [
                    measuredKickOverFoundationDB,
                    targetKickOverFoundationDB,
                    sourceKickRMS,
                    sourceKickActiveRMS,
                ].allSatisfy { $0 == nil } || (
                    measuredKickOverFoundationDB != nil &&
                    targetKickOverFoundationDB != nil &&
                    (sourceKickRMS ?? 0) > 0 &&
                    (sourceKickActiveRMS ?? 0) > 0
                )
            )
    }
}

/// One bounded record per rendered bar binds the score-owned kick syntax to the
/// exact detector and post-fader kick consequences from detached preparation.
/// It retains no PCM; its reduced dimensions participate only through the
/// exact installed professional-quality profile and primary evaluator.
package struct AutonomousKickSourceDynamicsEvidence: Codable, Equatable,
        Sendable {
    package let version: String
    package let antialiasOrder: Int
    package let morphologyVersion: String
    package let morphologyScoreHash: String
    package let morphologyFromHome: String
    package let morphologyToHome: String
    package let morphologyStartProgress: Double
    package let morphologyEndProgress: Double
    package let fundamentalStartHz: Double
    package let fundamentalEndHz: Double
    package let pitchDepthStartHz: Double
    package let pitchDepthEndHz: Double
    package let bodyDecayStartPerSecond: Double
    package let bodyDecayEndPerSecond: Double
    package let clickLevelStart: Double
    package let clickLevelEnd: Double
    package let bodyDriveStart: Double
    package let bodyDriveEnd: Double
    package let morphologyBound: Bool
    package let renderedEventCount: Int
    package let processedSampleCount: Int
    package let inputSampleHash: String
    package let outputSampleHash: String
    package let inputPeak: Double
    package let inputRMS: Double
    package let inputCrestFactor: Double
    package let outputPeak: Double
    package let outputRMS: Double
    package let outputCrestFactor: Double
    package let inputAttackRMS: Double
    package let outputAttackRMS: Double
    package let inputBodyRMS: Double
    package let outputBodyRMS: Double
    package let inputUpperMidEnergyRatio: Double
    package let outputUpperMidEnergyRatio: Double
    package let finite: Bool

    package init(render: KickSourceDynamicsRenderEvidence) {
        version = render.version
        antialiasOrder = render.antialiasOrder
        morphologyVersion = render.morphologyVersion
        morphologyScoreHash = render.morphologyScoreHash
        morphologyFromHome = render.morphologyFromHome
        morphologyToHome = render.morphologyToHome
        morphologyStartProgress = render.morphologyStartProgress
        morphologyEndProgress = render.morphologyEndProgress
        fundamentalStartHz = render.fundamentalStartHz
        fundamentalEndHz = render.fundamentalEndHz
        pitchDepthStartHz = render.pitchDepthStartHz
        pitchDepthEndHz = render.pitchDepthEndHz
        bodyDecayStartPerSecond = render.bodyDecayStartPerSecond
        bodyDecayEndPerSecond = render.bodyDecayEndPerSecond
        clickLevelStart = render.clickLevelStart
        clickLevelEnd = render.clickLevelEnd
        bodyDriveStart = render.bodyDriveStart
        bodyDriveEnd = render.bodyDriveEnd
        morphologyBound = render.morphologyBound
        renderedEventCount = render.renderedEventCount
        processedSampleCount = render.processedSampleCount
        inputSampleHash = render.inputSampleHash
        outputSampleHash = render.outputSampleHash
        inputPeak = render.inputPeak
        inputRMS = render.inputRMS
        inputCrestFactor = render.inputCrestFactor
        outputPeak = render.outputPeak
        outputRMS = render.outputRMS
        outputCrestFactor = render.outputCrestFactor
        inputAttackRMS = render.inputAttackRMS
        outputAttackRMS = render.outputAttackRMS
        inputBodyRMS = render.inputBodyRMS
        outputBodyRMS = render.outputBodyRMS
        inputUpperMidEnergyRatio = render.inputUpperMidEnergyRatio
        outputUpperMidEnergyRatio = render.outputUpperMidEnergyRatio
        finite = render.finite
    }

    package var isFinite: Bool {
        [
            inputPeak, inputRMS, inputCrestFactor, outputPeak, outputRMS,
            outputCrestFactor, inputAttackRMS, outputAttackRMS, inputBodyRMS,
            outputBodyRMS, inputUpperMidEnergyRatio,
            outputUpperMidEnergyRatio, morphologyStartProgress,
            morphologyEndProgress, fundamentalStartHz, fundamentalEndHz,
            pitchDepthStartHz, pitchDepthEndHz, bodyDecayStartPerSecond,
            bodyDecayEndPerSecond, clickLevelStart, clickLevelEnd,
            bodyDriveStart, bodyDriveEnd,
        ].allSatisfy(\.isFinite)
    }

    package func isComplete(
        sampleRate: Double,
        expectedEventCount: Int
    ) -> Bool {
        guard version == KickSourceDynamicsContract.version,
              antialiasOrder == KickSourceDynamicsContract.antialiasOrder,
              morphologyVersion == KickMorphologyResolver.version,
              Self.isSampleHash(morphologyScoreHash),
              KickMorphologyHome(rawValue: morphologyFromHome) != nil,
              KickMorphologyHome(rawValue: morphologyToHome) != nil,
              morphologyFromHome != morphologyToHome,
              morphologyBound,
              (0...1).contains(morphologyStartProgress),
              (0...1).contains(morphologyEndProgress),
              morphologyEndProgress >= morphologyStartProgress,
              (38...52).contains(fundamentalStartHz),
              (38...52).contains(fundamentalEndHz),
              (140...300).contains(pitchDepthStartHz),
              (140...300).contains(pitchDepthEndHz),
              (13...24).contains(bodyDecayStartPerSecond),
              (13...24).contains(bodyDecayEndPerSecond),
              (0.045...0.11).contains(clickLevelStart),
              (0.045...0.11).contains(clickLevelEnd),
              (1.05...1.42).contains(bodyDriveStart),
              (1.05...1.42).contains(bodyDriveEnd),
              renderedEventCount == expectedEventCount,
              (0...KickSourceDynamicsContract.maximumEventsPerBar)
                .contains(renderedEventCount),
              processedSampleCount >= 0,
              processedSampleCount <= KickSourceDynamicsContract
                .maximumProcessedSampleCount(sampleRate: sampleRate),
              Self.isSampleHash(inputSampleHash),
              Self.isSampleHash(outputSampleHash),
              finite, isFinite,
              inputPeak >= 0,
              inputPeak <= Double(Float.greatestFiniteMagnitude),
              inputRMS >= 0, inputRMS <= inputPeak,
              outputPeak >= 0,
              outputPeak <= Double(Float(KickSourceDynamicsContract.outputGain)),
              outputRMS >= 0, outputRMS <= outputPeak,
              inputCrestFactor >= 0,
              outputCrestFactor >= 0,
              inputAttackRMS >= 0, outputAttackRMS >= 0,
              inputBodyRMS >= 0, outputBodyRMS >= 0,
              (0...1).contains(inputUpperMidEnergyRatio),
              (0...1).contains(outputUpperMidEnergyRatio) else {
            return false
        }
        if renderedEventCount == 0 {
            let empty = KickSourceDynamicsRenderEvidence.empty
            return processedSampleCount == 0 &&
                inputSampleHash == empty.inputSampleHash &&
                outputSampleHash == empty.outputSampleHash &&
                inputPeak.bitPattern == 0 && inputRMS.bitPattern == 0 &&
                inputCrestFactor.bitPattern == 0 &&
                outputPeak.bitPattern == 0 && outputRMS.bitPattern == 0 &&
                outputCrestFactor.bitPattern == 0 &&
                inputAttackRMS.bitPattern == 0 &&
                outputAttackRMS.bitPattern == 0 &&
                inputBodyRMS.bitPattern == 0 &&
                outputBodyRMS.bitPattern == 0 &&
                inputUpperMidEnergyRatio.bitPattern == 0 &&
                outputUpperMidEnergyRatio.bitPattern == 0
        }
        return processedSampleCount > 0 && inputPeak > 0 && inputRMS > 0 &&
            outputPeak > 0 && outputRMS > 0 && inputAttackRMS > 0 &&
            outputAttackRMS > 0 && inputBodyRMS > 0 && outputBodyRMS > 0 &&
            inputSampleHash != outputSampleHash &&
            inputCrestFactor == inputPeak / inputRMS &&
            outputCrestFactor == outputPeak / outputRMS
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.utf8.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

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
    package let sourceDynamics: AutonomousKickSourceDynamicsEvidence
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
        sourceDynamics: AutonomousKickSourceDynamicsEvidence,
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
        self.sourceDynamics = sourceDynamics
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
              sourceDynamics.isComplete(
                sampleRate: sampleRate,
                expectedEventCount: renderedKickEventCount
              ),
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

/// One bounded record per rendered bar binds the score-owned two-bar
/// foundation relation to the exact existing Resonant Mono render calls and
/// dry foundation consequence. No sample arrays survive reduction.
package struct AutonomousFoundationPreKickPocketEvidence:
    Codable, Equatable, Sendable
{
    package let relation: String?
    package let scoreEventIndex: Int
    package let bassStep: Int
    package let kickStep: Int
    package let eventStartFrame: Int
    package let naturalEndFrame: Int
    package let releaseStartFrame: Int
    package let releaseEndFrame: Int
    package let kickFrame: Int
    package let releaseFrameCount: Int
    package let silenceFrameCount: Int
    package let silenceSampleHash: String
    package let silencePeak: Double
    package let silenceRMS: Double
    package let applied: Bool
    package let finite: Bool

    package init(render: FoundationPreKickPocketRenderEvidence) {
        relation = render.relation?.rawValue
        scoreEventIndex = render.scoreEventIndex
        bassStep = render.bassStep
        kickStep = render.kickStep
        eventStartFrame = render.eventStartFrame
        naturalEndFrame = render.naturalEndFrame
        releaseStartFrame = render.releaseStartFrame
        releaseEndFrame = render.releaseEndFrame
        kickFrame = render.kickFrame
        releaseFrameCount = render.releaseFrameCount
        silenceFrameCount = render.silenceFrameCount
        silenceSampleHash = render.silenceSampleHash
        silencePeak = render.silencePeak
        silenceRMS = render.silenceRMS
        applied = render.applied
        finite = render.finite
    }

    package static let neutral = AutonomousFoundationPreKickPocketEvidence(
        render: .neutral
    )

    package func isComplete(
        sampleRate: Double,
        renderedFrameCount: Int
    ) -> Bool {
        guard relation != nil else { return self == .neutral }
        guard FoundationPreKickPocketRelation(rawValue: relation ?? "") ==
                .preKickClearance,
              sampleRate.isFinite,
              sampleRate > 0,
              (0..<64).contains(scoreEventIndex),
              (0..<15).contains(bassStep),
              kickStep == bassStep + 1,
              FoundationRhythmicRelationContract.requiredKickSteps.contains(
                kickStep
              ),
              eventStartFrame >= 0,
              eventStartFrame < releaseStartFrame,
              releaseStartFrame < releaseEndFrame,
              releaseEndFrame < kickFrame,
              naturalEndFrame > kickFrame,
              kickFrame <= renderedFrameCount,
              releaseFrameCount == releaseEndFrame - releaseStartFrame,
              releaseFrameCount > 0,
              silenceFrameCount == kickFrame - releaseEndFrame,
              silenceFrameCount > 0,
              silenceSampleHash.count == 16,
              silenceSampleHash.utf8.allSatisfy({ byte in
                  (48...57).contains(byte) || (97...102).contains(byte)
              }),
              silencePeak == 0,
              silenceRMS == 0,
              applied,
              finite else {
            return false
        }
        let stepFrames = Double(renderedFrameCount) / 16.0
        let expectedKickFrame = Int((Double(kickStep) * stepFrames).rounded())
        let expectedReleaseStart = Int(((
            Double(kickStep) -
                FoundationPreKickPocketContract.releaseLeadInSteps
        ) * stepFrames).rounded())
        let expectedReleaseEnd = Int(((
            Double(kickStep) -
                FoundationPreKickPocketContract.silenceLeadInSteps
        ) * stepFrames).rounded())
        return kickFrame == expectedKickFrame &&
            releaseStartFrame == expectedReleaseStart &&
            releaseEndFrame == expectedReleaseEnd
    }
}

package struct AutonomousFoundationRhythmBarEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let relation: String
    package let pairPhase: Int
    package let scoreBassEventCount: Int
    package let scoreBassStepMask: UInt16
    package let renderedBassEventCount: Int
    package let renderedBassStepMask: UInt16
    package let renderedFrameCount: Int
    package let renderedStartFrameFingerprint: String
    package let dryFoundationSampleHash: String
    package let peak: Double
    package let rms: Double
    package let bassPluckAssigned: Bool
    package let preKickPocket: AutonomousFoundationPreKickPocketEvidence
    package let renderPassesMatch: Bool
    package let bindingValid: Bool
    package let finite: Bool

    package init(
        bar: Int,
        relation: FoundationRhythmicRelation,
        pairPhase: Int,
        scoreBassEventCount: Int,
        scoreBassStepMask: UInt16,
        renderedBassEventCount: Int,
        renderedBassStepMask: UInt16,
        renderedFrameCount: Int,
        renderedStartFrameFingerprint: String,
        dryFoundationSampleHash: String,
        peak: Double,
        rms: Double,
        bassPluckAssigned: Bool,
        preKickPocket: AutonomousFoundationPreKickPocketEvidence = .neutral,
        renderPassesMatch: Bool,
        bindingValid: Bool,
        finite: Bool
    ) {
        self.bar = bar
        self.relation = relation.rawValue
        self.pairPhase = pairPhase
        self.scoreBassEventCount = scoreBassEventCount
        self.scoreBassStepMask = scoreBassStepMask
        self.renderedBassEventCount = renderedBassEventCount
        self.renderedBassStepMask = renderedBassStepMask
        self.renderedFrameCount = renderedFrameCount
        self.renderedStartFrameFingerprint = renderedStartFrameFingerprint
        self.dryFoundationSampleHash = dryFoundationSampleHash
        self.peak = peak
        self.rms = rms
        self.bassPluckAssigned = bassPluckAssigned
        self.preKickPocket = preKickPocket
        self.renderPassesMatch = renderPassesMatch
        self.bindingValid = bindingValid
        self.finite = finite
    }

    package var isFinite: Bool {
        finite && peak.isFinite && rms.isFinite &&
            preKickPocket.silencePeak.isFinite &&
            preKickPocket.silenceRMS.isFinite
    }

    package func isComplete(sampleRate: Double) -> Bool {
        guard let resolvedRelation = FoundationRhythmicRelation(
                rawValue: relation
              ),
              bar >= 0,
              pairPhase == FoundationRhythmicRelationContract.pairPhase(
                absoluteBar: bar
              ),
              sampleRate.isFinite,
              (QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate)
                .contains(sampleRate),
              renderedFrameCount == Int(
                (240.0 / AutonomousSessionDirector.bpm * sampleRate).rounded()
              ),
              (0...16).contains(scoreBassEventCount),
              (0...16).contains(renderedBassEventCount),
              scoreBassEventCount == renderedBassEventCount,
              scoreBassStepMask == renderedBassStepMask,
              scoreBassEventCount == 0
                ? scoreBassStepMask == 0
                : scoreBassStepMask.nonzeroBitCount > 0 &&
                    scoreBassStepMask.nonzeroBitCount <= scoreBassEventCount,
              Self.isSampleHash(renderedStartFrameFingerprint),
              Self.isSampleHash(dryFoundationSampleHash),
              peak >= 0,
              peak <= Double(Float.greatestFiniteMagnitude),
              rms >= 0,
              rms <= peak,
              isFinite,
              renderPassesMatch,
              bindingValid else {
            return false
        }
        switch resolvedRelation {
        case .established:
            return preKickPocket == .neutral &&
                (scoreBassEventCount == 0 || (peak > 0 && rms > 0))
        case .dottedThreeSixteenth:
            return scoreBassEventCount == 4 && bassPluckAssigned &&
                scoreBassStepMask == FoundationRhythmicRelationContract
                    .stepMask(pairPhase: pairPhase) &&
                peak > 0 && rms > 0 &&
                preKickPocket.isComplete(
                    sampleRate: sampleRate,
                    renderedFrameCount: renderedFrameCount
                ) &&
                preKickPocket.bassStep == (pairPhase == 0 ? 3 : 11) &&
                preKickPocket.kickStep == (pairPhase == 0 ? 4 : 12)
        }
    }

    package static func startFrameFingerprint(_ frames: [Int]) -> String {
        var sink = StreamingFNV1a()
        sink.domain("foundation-rhythm-start-frames.typed.v1")
        sink.collection(frames.count)
        for frame in frames { sink.int(frame) }
        return fixedWidthFingerprintHex(sink.value)
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

package enum AutonomousClimaxArcRelation: String, Codable, Equatable, Sendable {
    case none
    case dramaticDebtRelease = "dramatic-debt-release"
    case dramaticDebtRecovery = "dramatic-debt-recovery"
}

/// Compact same-pass proof that the final withheld climax bar closes into an
/// exact terminal absence before the unchanged recovery boundary.
package struct AutonomousClimaxHangEvidence: Codable, Equatable, Sendable {
    package let active: Bool
    package let relation: String?
    package let bar: Int?
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let startStep: Int
    package let endStep: Int
    package let releaseStartFrame: Int
    package let silenceStartFrame: Int
    package let releaseFrameCount: Int
    package let silenceFrameCount: Int
    package let preHangStereoSampleHash: String
    package let postHangStereoSampleHash: String
    package let silenceStereoSampleHash: String
    package let releaseInputRMS: Double
    package let silencePeak: Double
    package let silenceRMS: Double
    package let silenceNonzeroSampleCount: Int
    package let postHangMatchesLiveMasterInput: Bool
    package let bindingValid: Bool
    package let finite: Bool

    package init(
        render: ClimaxHangRenderEvidence,
        bar: Int?,
        postHangMatchesLiveMasterInput: Bool,
        bindingValid: Bool
    ) {
        active = render.active
        relation = render.relation?.rawValue
        self.bar = bar
        sampleRate = render.sampleRate
        renderedFrameCount = render.renderedFrameCount
        startStep = render.startStep
        endStep = render.endStep
        releaseStartFrame = render.releaseStartFrame
        silenceStartFrame = render.silenceStartFrame
        releaseFrameCount = render.releaseFrameCount
        silenceFrameCount = render.silenceFrameCount
        preHangStereoSampleHash = render.preHangStereoSampleHash
        postHangStereoSampleHash = render.postHangStereoSampleHash
        silenceStereoSampleHash = render.silenceStereoSampleHash
        releaseInputRMS = render.releaseInputRMS
        silencePeak = render.silencePeak
        silenceRMS = render.silenceRMS
        silenceNonzeroSampleCount = render.silenceNonzeroSampleCount
        self.postHangMatchesLiveMasterInput = postHangMatchesLiveMasterInput
        self.bindingValid = bindingValid
        finite = render.finite
    }

    package static let neutral = AutonomousClimaxHangEvidence(
        render: .neutral,
        bar: nil,
        postHangMatchesLiveMasterInput: true,
        bindingValid: true
    )

    package func isComplete(sampleRate expectedSampleRate: Double) -> Bool {
        guard active else { return self == .neutral }
        guard relation == ClimaxHangRelation.terminalRecoveryDelay.rawValue,
              let bar,
              bar >= 0,
              sampleRate == expectedSampleRate,
              sampleRate.isFinite,
              sampleRate >=
                QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <=
                QualityQualificationContract.maximumSupportedSampleRate,
              renderedFrameCount == Int((
                240.0 / AutonomousSessionDirector.bpm * sampleRate
              ).rounded()),
              startStep == ClimaxHangContract.startStep,
              endStep == ClimaxHangContract.endStep,
              releaseStartFrame >= 0,
              releaseStartFrame < silenceStartFrame,
              silenceStartFrame == Int((
                Double(startStep) * Double(renderedFrameCount) / 16
              ).rounded()),
              releaseFrameCount == silenceStartFrame - releaseStartFrame,
              releaseFrameCount == max(
                1,
                Int((sampleRate * ClimaxHangRenderer.releaseSeconds).rounded())
              ),
              silenceFrameCount == renderedFrameCount - silenceStartFrame,
              releaseInputRMS > 0,
              silencePeak == 0,
              silenceRMS == 0,
              silenceNonzeroSampleCount == 0,
              Self.isFingerprint(preHangStereoSampleHash),
              Self.isFingerprint(postHangStereoSampleHash),
              Self.isFingerprint(silenceStereoSampleHash),
              silenceStereoSampleHash == ExactPCMFingerprint.stereoZero(
                sampleCount: silenceFrameCount
              ),
              preHangStereoSampleHash != postHangStereoSampleHash,
              postHangMatchesLiveMasterInput,
              bindingValid,
              finite else {
            return false
        }
        return true
    }

    private static func isFingerprint(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Compact proof that a committed release pays a previously opened dramatic
/// obligation and, when present, resolves through the existing kick-syntax
/// recovery. The record owns no new score or PCM; it binds long-form cause to
/// the already attributable release and optional grounded/withheld/recovery
/// consequence.
package struct AutonomousClimaxArcEvidence: Codable, Equatable, Sendable {
    package static let maximumDebtCount = 128

    package let relation: String
    package let paidDebtCount: Int
    package let contrastDebtCount: Int
    package let majorBreakDebtCount: Int
    package let sourceDebtFingerprint: String
    package let earliestOpenedAtBar: Int?
    package let latestOpenedAtBar: Int?
    package let latestDueByBar: Int?
    package let releaseStartBar: Int
    package let setupBar: Int?
    package let firstWithheldBar: Int?
    package let secondWithheldBar: Int?
    package let recoveryBar: Int?
    package let hang: AutonomousClimaxHangEvidence
    package let bindingValid: Bool

    package init(
        relation: AutonomousClimaxArcRelation,
        paidDebtCount: Int,
        contrastDebtCount: Int,
        majorBreakDebtCount: Int,
        sourceDebtFingerprint: String,
        earliestOpenedAtBar: Int?,
        latestOpenedAtBar: Int?,
        latestDueByBar: Int?,
        releaseStartBar: Int,
        setupBar: Int?,
        firstWithheldBar: Int?,
        secondWithheldBar: Int?,
        recoveryBar: Int?,
        hang: AutonomousClimaxHangEvidence,
        bindingValid: Bool
    ) {
        self.relation = relation.rawValue
        self.paidDebtCount = paidDebtCount
        self.contrastDebtCount = contrastDebtCount
        self.majorBreakDebtCount = majorBreakDebtCount
        self.sourceDebtFingerprint = sourceDebtFingerprint
        self.earliestOpenedAtBar = earliestOpenedAtBar
        self.latestOpenedAtBar = latestOpenedAtBar
        self.latestDueByBar = latestDueByBar
        self.releaseStartBar = releaseStartBar
        self.setupBar = setupBar
        self.firstWithheldBar = firstWithheldBar
        self.secondWithheldBar = secondWithheldBar
        self.recoveryBar = recoveryBar
        self.hang = hang
        self.bindingValid = bindingValid
    }

    package static func inactive(
        releaseStartBar: Int,
        bindingValid: Bool = true
    ) -> Self {
        Self(
            relation: .none,
            paidDebtCount: 0,
            contrastDebtCount: 0,
            majorBreakDebtCount: 0,
            sourceDebtFingerprint: debtFingerprint([]),
            earliestOpenedAtBar: nil,
            latestOpenedAtBar: nil,
            latestDueByBar: nil,
            releaseStartBar: releaseStartBar,
            setupBar: nil,
            firstWithheldBar: nil,
            secondWithheldBar: nil,
            recoveryBar: nil,
            hang: .neutral,
            bindingValid: bindingValid
        )
    }

    package var recordIsStructurallyValid: Bool {
        let optionalBars = [
            earliestOpenedAtBar, latestOpenedAtBar, latestDueByBar, setupBar,
            firstWithheldBar, secondWithheldBar, recoveryBar,
        ].compactMap { $0 }
        return AutonomousClimaxArcRelation(rawValue: relation) != nil &&
            (0...Self.maximumDebtCount).contains(paidDebtCount) &&
            (0...Self.maximumDebtCount).contains(contrastDebtCount) &&
            (0...Self.maximumDebtCount).contains(majorBreakDebtCount) &&
            contrastDebtCount <= paidDebtCount &&
            majorBreakDebtCount <= paidDebtCount &&
            contrastDebtCount <= paidDebtCount - majorBreakDebtCount &&
            Self.isFingerprint(sourceDebtFingerprint) && releaseStartBar >= 0 &&
            optionalBars.allSatisfy { $0 >= 0 }
    }

    package func isComplete(
        phraseKind: String,
        startBar: Int,
        declaredBarCount: Int,
        kickSyntax: [AutonomousKickSyntaxBarEvidence],
        sampleRate: Double
    ) -> Bool {
        guard recordIsStructurallyValid, bindingValid,
              releaseStartBar == startBar,
              declaredBarCount > 0,
              startBar <= Int.max - declaredBarCount,
              let relation = AutonomousClimaxArcRelation(rawValue: relation),
              let kind = AutonomousPhraseKind(rawValue: phraseKind) else {
            return false
        }
        let roles = kickSyntax.compactMap { KickSyntaxRole(rawValue: $0.role) }
        guard roles.count == kickSyntax.count else { return false }

        switch relation {
        case .none:
            return paidDebtCount == 0 && contrastDebtCount == 0 &&
                majorBreakDebtCount == 0 &&
                sourceDebtFingerprint == Self.debtFingerprint([]) &&
                earliestOpenedAtBar == nil && latestOpenedAtBar == nil &&
                latestDueByBar == nil && setupBar == nil &&
                firstWithheldBar == nil && secondWithheldBar == nil &&
                recoveryBar == nil && hang == .neutral &&
                roles.allSatisfy { $0 == .grounded }
        case .dramaticDebtRelease, .dramaticDebtRecovery:
            guard kind == .energyRelease,
                  paidDebtCount > 0,
                  contrastDebtCount + majorBreakDebtCount == paidDebtCount,
                  let earliestOpenedAtBar,
                  let latestOpenedAtBar,
                  let latestDueByBar,
                  earliestOpenedAtBar <= latestOpenedAtBar,
                  latestOpenedAtBar < releaseStartBar,
                  latestDueByBar >= latestOpenedAtBar else {
                return false
            }
            if relation == .dramaticDebtRelease {
                return setupBar == nil && firstWithheldBar == nil &&
                    secondWithheldBar == nil && recoveryBar == nil &&
                    hang == .neutral &&
                    roles.allSatisfy { $0 == .grounded }
            }
            guard let setupBar,
                  let firstWithheldBar,
                  let secondWithheldBar,
                  let recoveryBar,
                  setupBar >= startBar,
                  recoveryBar < startBar + declaredBarCount,
                  setupBar <= Int.max - 3,
                  firstWithheldBar == setupBar + 1,
                  secondWithheldBar == setupBar + 2,
                  recoveryBar == setupBar + 3,
                  Self.macroPosition(recoveryBar) == 15 else {
                return false
            }
            guard let setupIndex = kickSyntax.firstIndex(where: {
                $0.bar == setupBar
            }), setupIndex <= kickSyntax.count - 4 else {
                return false
            }
            return hang.bar == secondWithheldBar &&
                hang.isComplete(sampleRate: sampleRate) &&
                kickSyntax[setupIndex].role == KickSyntaxRole.grounded.rawValue &&
                kickSyntax[setupIndex + 1].bar == firstWithheldBar &&
                kickSyntax[setupIndex + 1].role == KickSyntaxRole.withheld.rawValue &&
                kickSyntax[setupIndex + 2].bar == secondWithheldBar &&
                kickSyntax[setupIndex + 2].role == KickSyntaxRole.withheld.rawValue &&
                kickSyntax[setupIndex + 3].bar == recoveryBar &&
                kickSyntax[setupIndex + 3].role == KickSyntaxRole.recovery.rawValue
        }
    }

    package static func debtFingerprint(
        _ debts: [SessionDramaticDebt]
    ) -> String {
        var sink = StreamingFNV1a()
        sink.domain("climax-arc-dramatic-debts.typed.v1")
        sink.collection(debts.count)
        for debt in debts {
            sink.aggregate("SessionDramaticDebt")
            sink.field("id"); sink.int(debt.id)
            sink.field("openedAtBar"); sink.int(debt.openedAtBar)
            sink.field("dueByBar"); sink.int(debt.dueByBar)
            sink.field("source"); sink.raw(debt.source.rawValue)
        }
        return fixedWidthFingerprintHex(sink.value)
    }

    private static func macroPosition(_ bar: Int) -> Int {
        let remainder = bar % 16
        return remainder >= 0 ? remainder : remainder + 16
    }

    private static func isFingerprint(_ value: String) -> Bool {
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
    package let pitchIdentity: String
    package let color: Double
    package let shape: Double
    package let motion: Double
    package let space: Double
    package let effects: [String]

    package init(_ assignment: InstrumentAssignment) {
        use = assignment.use.rawValue
        architecture = assignment.architecture.rawValue
        patch = assignment.patch.rawValue
        pitchIdentity = assignment.musicalPitchIdentity.rawValue
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
        let assignment = InstrumentAssignment(
            use: use,
            patch: patch,
            automation: InstrumentAutomation(
                color: color,
                shape: shape,
                motion: motion,
                space: space
            ),
            effects: effects.compactMap(InstrumentEffect.init(rawValue:))
        )
        return [color, shape, motion, space].allSatisfy { (0...1).contains($0) } &&
            (use != .foundationBass || space == 0) &&
            pitchIdentity == assignment.musicalPitchIdentity.rawValue
    }
}

/// Compact, versioned proof that the score-owned acid relation reached the
/// current two-operator renderer. Semantic relation counts survive future DSP
/// replacement; the numeric ratio/index facts identify this implementation.
package struct AutonomousResonantMonoModulationEvidence: Codable, Equatable,
        Sendable {
    package let sourceAssignmentCount: Int
    package let eventCount: Int
    package let orderedEventCount: Int
    package let metallicEventCount: Int
    package let orderedModulatorRatio: Double
    package let metallicModulatorRatio: Double
    package let maximumRequestedPeakIndex: Double
    package let minimumAppliedPeakIndex: Double
    package let maximumAppliedPeakIndex: Double
    package let eventFingerprint: String
    package let operatorSampleHash: String
    package let operatorPeak: Double
    package let operatorRMS: Double
    package let operatorCrestFactor: Double
    package let lowBandEnergyRatio: Double
    package let bindingValid: Bool
    package let finite: Bool

    package init(_ evidence: ResonantMonoModulationRenderEvidence) {
        sourceAssignmentCount = evidence.sourceAssignmentCount
        eventCount = evidence.eventCount
        orderedEventCount = evidence.orderedEventCount
        metallicEventCount = evidence.metallicEventCount
        orderedModulatorRatio = evidence.orderedModulatorRatio
        metallicModulatorRatio = evidence.metallicModulatorRatio
        maximumRequestedPeakIndex = evidence.maximumRequestedPeakIndex
        minimumAppliedPeakIndex = evidence.minimumAppliedPeakIndex
        maximumAppliedPeakIndex = evidence.maximumAppliedPeakIndex
        eventFingerprint = evidence.eventFingerprint
        operatorSampleHash = evidence.operatorSampleHash
        operatorPeak = evidence.operatorPeak
        operatorRMS = evidence.operatorRMS
        operatorCrestFactor = evidence.operatorCrestFactor
        lowBandEnergyRatio = evidence.lowBandEnergyRatio
        bindingValid = evidence.bindingValid
        finite = evidence.finite
    }

    package var isFinite: Bool {
        finite && [
            orderedModulatorRatio, metallicModulatorRatio,
            maximumRequestedPeakIndex, minimumAppliedPeakIndex,
            maximumAppliedPeakIndex, operatorPeak, operatorRMS,
            operatorCrestFactor, lowBandEnergyRatio,
        ].allSatisfy(\.isFinite)
    }

    package func isComplete(
        assignments: [AutonomousInstrumentAssignmentEvidence],
        architectureEventCount: Int
    ) -> Bool {
        let acid = assignments.filter {
            $0.patch == InstrumentPatch.acidThread.rawValue ||
                $0.patch == InstrumentPatch.acidSequence.rawValue
        }
        guard bindingValid, isFinite,
              sourceAssignmentCount == acid.count,
              sourceAssignmentCount > 0,
              eventCount >= sourceAssignmentCount,
              eventCount <=
                AutonomousCandidateEvaluationVector.maximumInstrumentEventsPerBar,
              architectureEventCount >= eventCount,
              orderedEventCount >= 0, orderedEventCount <= eventCount,
              metallicEventCount >= 0, metallicEventCount <= eventCount,
              orderedEventCount == eventCount - metallicEventCount,
              Self.isSampleHash(eventFingerprint),
              Self.isSampleHash(operatorSampleHash),
              operatorPeak > 0, operatorRMS > 0, operatorRMS <= operatorPeak,
              operatorCrestFactor == operatorPeak / operatorRMS,
              (0...ResonantMonoModulationContract.maximumLowBandEnergyRatio)
                .contains(lowBandEnergyRatio),
              maximumRequestedPeakIndex > 0,
              maximumRequestedPeakIndex <=
                ResonantMonoModulationContract.maximumRequestedPeakIndex,
              minimumAppliedPeakIndex > 0,
              minimumAppliedPeakIndex <= maximumAppliedPeakIndex,
              maximumAppliedPeakIndex <= maximumRequestedPeakIndex else {
            return false
        }
        let hasOrderedAssignment = acid.contains {
            $0.patch == InstrumentPatch.acidThread.rawValue
        }
        let hasMetallicAssignment = acid.contains {
            $0.patch == InstrumentPatch.acidSequence.rawValue
        }
        return (orderedEventCount > 0) == hasOrderedAssignment &&
            (metallicEventCount > 0) == hasMetallicAssignment &&
            orderedModulatorRatio == (hasOrderedAssignment ? 2.0 : 0) &&
            metallicModulatorRatio == (hasMetallicAssignment
                ? 1.414_213_562_373_095_1 : 0)
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

package struct AutonomousSpectralTextureClusterEvidence: Codable, Equatable, Sendable {
    package let sourceAssignmentCount: Int
    package let eventCount: Int
    package let relation: String
    package let adjacentRatio: Double
    package let maximumComponentRatio: Double
    package let minimumStartFrequency: Double
    package let maximumAppliedEndFrequency: Double
    package let eventFingerprint: String
    package let clusterSampleHash: String
    package let clusterPeak: Double
    package let clusterRMS: Double
    package let clusterCrestFactor: Double
    package let bindingValid: Bool
    package let finite: Bool

    package init(_ evidence: SpectralTextureClusterRenderEvidence) {
        sourceAssignmentCount = evidence.sourceAssignmentCount
        eventCount = evidence.eventCount
        relation = evidence.relation.rawValue
        adjacentRatio = evidence.adjacentRatio
        maximumComponentRatio = evidence.maximumComponentRatio
        minimumStartFrequency = evidence.minimumStartFrequency
        maximumAppliedEndFrequency = evidence.maximumAppliedEndFrequency
        eventFingerprint = evidence.eventFingerprint
        clusterSampleHash = evidence.clusterSampleHash
        clusterPeak = evidence.clusterPeak
        clusterRMS = evidence.clusterRMS
        clusterCrestFactor = evidence.clusterCrestFactor
        bindingValid = evidence.bindingValid
        finite = evidence.finite
    }

    package var isFinite: Bool {
        finite && [
            adjacentRatio, maximumComponentRatio, minimumStartFrequency,
            maximumAppliedEndFrequency, clusterPeak, clusterRMS,
            clusterCrestFactor,
        ].allSatisfy(\.isFinite)
    }

    package func isComplete(
        assignments: [AutonomousInstrumentAssignmentEvidence],
        architectureEventCount: Int,
        sampleRate: Double
    ) -> Bool {
        let clusterAssignments = assignments.filter {
            $0.patch == InstrumentPatch.metalVeil.rawValue &&
                $0.use == InstrumentUse.transition.rawValue
        }
        guard bindingValid, isFinite,
              sourceAssignmentCount == clusterAssignments.count,
              sourceAssignmentCount > 0,
              eventCount >= sourceAssignmentCount,
              eventCount <=
                AutonomousCandidateEvaluationVector.maximumInstrumentEventsPerBar,
              architectureEventCount >= eventCount,
              relation ==
                SpectralTextureClusterRelation.risingAdjacentCluster.rawValue,
              adjacentRatio ==
                SpectralTextureClusterContract.adjacentSemitoneRatio,
              maximumComponentRatio ==
                SpectralTextureClusterContract.maximumComponentRatio,
              sampleRate >=
                QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <=
                QualityQualificationContract.maximumSupportedSampleRate,
              minimumStartFrequency > 0,
              maximumAppliedEndFrequency > minimumStartFrequency,
              maximumAppliedEndFrequency * maximumComponentRatio <=
                sampleRate * 0.12,
              Self.isSampleHash(eventFingerprint),
              Self.isSampleHash(clusterSampleHash),
              clusterPeak > 0, clusterRMS > 0, clusterRMS <= clusterPeak,
              clusterCrestFactor == clusterPeak / clusterRMS,
              clusterPeak <= Double(Float.greatestFiniteMagnitude) else {
            return false
        }
        return true
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

package struct AutonomousSpectralTextureHarmonicTailEvidence: Codable,
        Equatable, Sendable {
    package let sourceAssignmentCount: Int
    package let eventCount: Int
    package let relation: String
    package let minimumFoldedSourceFrequency: Double
    package let maximumFoldedSourceFrequency: Double
    package let minimumBandCenterHz: Double
    package let maximumBandCenterHz: Double
    package let minimumResonance: Double
    package let maximumResonance: Double
    package let minimumPrefilterDrive: Double
    package let maximumPrefilterDrive: Double
    package let minimumLFORateHz: Double
    package let maximumLFORateHz: Double
    package let lowBandEnergyRatio: Double
    package let upperBandEnergyRatio: Double
    package let eventFingerprint: String
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let crestFactor: Double
    package let bindingValid: Bool
    package let finite: Bool

    package init(_ evidence: SpectralTextureHarmonicTailRenderEvidence) {
        sourceAssignmentCount = evidence.sourceAssignmentCount
        eventCount = evidence.eventCount
        relation = evidence.relation.rawValue
        minimumFoldedSourceFrequency = evidence.minimumFoldedSourceFrequency
        maximumFoldedSourceFrequency = evidence.maximumFoldedSourceFrequency
        minimumBandCenterHz = evidence.minimumBandCenterHz
        maximumBandCenterHz = evidence.maximumBandCenterHz
        minimumResonance = evidence.minimumResonance
        maximumResonance = evidence.maximumResonance
        minimumPrefilterDrive = evidence.minimumPrefilterDrive
        maximumPrefilterDrive = evidence.maximumPrefilterDrive
        minimumLFORateHz = evidence.minimumLFORateHz
        maximumLFORateHz = evidence.maximumLFORateHz
        lowBandEnergyRatio = evidence.lowBandEnergyRatio
        upperBandEnergyRatio = evidence.upperBandEnergyRatio
        eventFingerprint = evidence.eventFingerprint
        sampleHash = evidence.sampleHash
        peak = evidence.peak
        rms = evidence.rms
        crestFactor = evidence.crestFactor
        bindingValid = evidence.bindingValid
        finite = evidence.finite
    }

    package var isFinite: Bool {
        finite && [
            minimumFoldedSourceFrequency, maximumFoldedSourceFrequency,
            minimumBandCenterHz, maximumBandCenterHz,
            minimumResonance, maximumResonance,
            minimumPrefilterDrive, maximumPrefilterDrive,
            minimumLFORateHz, maximumLFORateHz,
            lowBandEnergyRatio, upperBandEnergyRatio,
            peak, rms, crestFactor,
        ].allSatisfy(\.isFinite)
    }

    package func isComplete(
        assignments: [AutonomousInstrumentAssignmentEvidence],
        architectureEventCount: Int,
        sampleRate: Double
    ) -> Bool {
        let tailAssignments = assignments.filter {
            $0.patch == InstrumentPatch.voltageArc.rawValue &&
                $0.use == InstrumentUse.response.rawValue
        }
        guard bindingValid, isFinite,
              sourceAssignmentCount == tailAssignments.count,
              sourceAssignmentCount > 0,
              eventCount >= sourceAssignmentCount,
              eventCount <=
                AutonomousCandidateEvaluationVector.maximumInstrumentEventsPerBar,
              architectureEventCount >= eventCount,
              relation ==
                SpectralTextureHarmonicTailRelation.drivenUpperBand.rawValue,
              minimumFoldedSourceFrequency >=
                SpectralTextureHarmonicTailContract.minimumSourceFrequency,
              maximumFoldedSourceFrequency >= minimumFoldedSourceFrequency,
              maximumFoldedSourceFrequency <=
                SpectralTextureHarmonicTailContract.maximumSourceFrequency,
              minimumBandCenterHz >=
                SpectralTextureHarmonicTailContract.minimumBandCenterHz(
                    sampleRate: sampleRate
                ),
              maximumBandCenterHz > minimumBandCenterHz,
              maximumBandCenterHz <=
                SpectralTextureHarmonicTailContract.maximumBandCenterHz(
                    sampleRate: sampleRate
                ),
              minimumResonance >= 2.2,
              maximumResonance >= minimumResonance,
              maximumResonance <= 6.4,
              minimumPrefilterDrive > 1,
              maximumPrefilterDrive >= minimumPrefilterDrive,
              maximumPrefilterDrive <= 3,
              minimumLFORateHz >= 2.4,
              maximumLFORateHz >= minimumLFORateHz,
              maximumLFORateHz <= 6,
              lowBandEnergyRatio >=
                SpectralTextureHarmonicTailContract.minimumLowBandEnergyRatio,
              lowBandEnergyRatio <=
                SpectralTextureHarmonicTailContract.maximumLowBandEnergyRatio,
              upperBandEnergyRatio >=
                SpectralTextureHarmonicTailContract.minimumUpperBandEnergyRatio,
              upperBandEnergyRatio <= 1,
              Self.isSampleHash(eventFingerprint),
              Self.isSampleHash(sampleHash),
              peak > 0, rms > 0, rms <= peak,
              crestFactor == peak / rms,
              peak <= Double(Float.greatestFiniteMagnitude) else {
            return false
        }
        return true
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Candidate-safe projection of the exact indefinite-pitch render proof.
/// Completeness fails closed when a texture follows note frequency, retains a
/// strong periodic fundamental, or lacks isolated dry PCM.
package struct AutonomousIndefinitePitchEvidence: Codable, Equatable, Sendable {
    package let evidenceVersion: String
    package let sourceAssignmentCount: Int
    package let eventCount: Int
    package let noteFrequencyInfluenceDisabled: Bool
    package let eventFingerprint: String
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let crestFactor: Double
    package let maximumNormalizedPeriodicity: Double
    package let analyzedSampleCount: Int
    package let bindingValid: Bool
    package let finite: Bool

    package init(_ evidence: IndefinitePitchRenderEvidence) {
        evidenceVersion = evidence.evidenceVersion
        sourceAssignmentCount = evidence.sourceAssignmentCount
        eventCount = evidence.eventCount
        noteFrequencyInfluenceDisabled =
            evidence.noteFrequencyInfluenceDisabled
        eventFingerprint = evidence.eventFingerprint
        sampleHash = evidence.sampleHash
        peak = evidence.peak
        rms = evidence.rms
        crestFactor = evidence.crestFactor
        maximumNormalizedPeriodicity =
            evidence.maximumNormalizedPeriodicity
        analyzedSampleCount = evidence.analyzedSampleCount
        bindingValid = evidence.bindingValid
        finite = evidence.finite
    }

    package var isFinite: Bool {
        finite && [
            peak, rms, crestFactor, maximumNormalizedPeriodicity,
        ].allSatisfy(\.isFinite)
    }

    package func isComplete(
        assignments: [AutonomousInstrumentAssignmentEvidence],
        architectureEventCount: Int
    ) -> Bool {
        let indefiniteAssignments = assignments.filter {
            $0.pitchIdentity == MusicalPitchIdentity.indefinitePitch.rawValue
        }
        return bindingValid && isFinite &&
            evidenceVersion == IndefinitePitchContract.evidenceVersion &&
            sourceAssignmentCount == indefiniteAssignments.count &&
            sourceAssignmentCount > 0 &&
            eventCount >= sourceAssignmentCount &&
            eventCount <=
                AutonomousCandidateEvaluationVector.maximumInstrumentEventsPerBar &&
            architectureEventCount >= eventCount &&
            noteFrequencyInfluenceDisabled &&
            Self.isSampleHash(eventFingerprint) &&
            Self.isSampleHash(sampleHash) &&
            peak > 0 && rms > 0 && rms <= peak &&
            crestFactor == peak / rms &&
            (0...IndefinitePitchContract.maximumNormalizedPeriodicity)
                .contains(maximumNormalizedPeriodicity) &&
            analyzedSampleCount >= 128 &&
            analyzedSampleCount <=
                IndefinitePitchContract.maximumAnalyzedSampleCount
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Candidate-safe projection of the exact samples and bounded parameters that
/// passed through the shared TPT/ADAA core. It carries only scalar facts and
/// fingerprints; no reconstructable PCM or mutable renderer state survives.
package struct AutonomousTPTAntialiasedNonlinearCoreEvidence: Codable, Equatable,
        Sendable {
    package let version: String
    package let antialiasOrder: Int
    package let sourceAssignmentCount: Int
    package let sourceEventCount: Int
    package let processedSampleCount: Int
    package let minimumCutoffHz: Double
    package let maximumCutoffHz: Double
    package let minimumQ: Double
    package let maximumQ: Double
    package let minimumInputDrive: Double
    package let maximumInputDrive: Double
    package let minimumOutputDrive: Double
    package let maximumOutputDrive: Double
    package let minimumBandMix: Double
    package let maximumBandMix: Double
    package let inputSampleHash: String
    package let outputSampleHash: String
    package let inputPeak: Double
    package let inputRMS: Double
    package let outputPeak: Double
    package let outputRMS: Double
    package let bindingValid: Bool
    package let finite: Bool

    package init(_ evidence: TPTAntialiasedNonlinearCoreRenderEvidence) {
        version = evidence.version
        antialiasOrder = evidence.antialiasOrder
        sourceAssignmentCount = evidence.sourceAssignmentCount
        sourceEventCount = evidence.sourceEventCount
        processedSampleCount = evidence.processedSampleCount
        minimumCutoffHz = evidence.minimumCutoffHz
        maximumCutoffHz = evidence.maximumCutoffHz
        minimumQ = evidence.minimumQ
        maximumQ = evidence.maximumQ
        minimumInputDrive = evidence.minimumInputDrive
        maximumInputDrive = evidence.maximumInputDrive
        minimumOutputDrive = evidence.minimumOutputDrive
        maximumOutputDrive = evidence.maximumOutputDrive
        minimumBandMix = evidence.minimumBandMix
        maximumBandMix = evidence.maximumBandMix
        inputSampleHash = evidence.inputSampleHash
        outputSampleHash = evidence.outputSampleHash
        inputPeak = evidence.inputPeak
        inputRMS = evidence.inputRMS
        outputPeak = evidence.outputPeak
        outputRMS = evidence.outputRMS
        bindingValid = evidence.bindingValid
        finite = evidence.finite
    }

    package var isFinite: Bool {
        finite && [
            minimumCutoffHz, maximumCutoffHz, minimumQ, maximumQ,
            minimumInputDrive, maximumInputDrive, minimumOutputDrive,
            maximumOutputDrive, minimumBandMix, maximumBandMix, inputPeak,
            inputRMS, outputPeak, outputRMS,
        ].allSatisfy(\.isFinite)
    }

    package func isComplete(
        architectureAssignmentCount: Int,
        architectureEventCount: Int,
        sampleRate: Double
    ) -> Bool {
        guard bindingValid, isFinite,
              version == TPTAntialiasedNonlinearCoreContract.version,
              antialiasOrder ==
                TPTAntialiasedNonlinearCoreContract.antialiasOrder,
              sourceAssignmentCount == architectureAssignmentCount,
              sourceEventCount == architectureEventCount,
              processedSampleCount >= sourceEventCount,
              sampleRate >=
                QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <=
                QualityQualificationContract.maximumSupportedSampleRate else {
            return false
        }
        let maximumFramesPerEvent = Int(ceil(
            sampleRate * 240.0 / AutonomousSessionDirector.bpm
        ))
        guard processedSampleCount <=
                sourceEventCount * maximumFramesPerEvent,
              minimumCutoffHz >=
                TPTAntialiasedNonlinearCoreContract.minimumCutoffHz,
              minimumCutoffHz <= maximumCutoffHz,
              maximumCutoffHz <= sampleRate *
                TPTAntialiasedNonlinearCoreContract.maximumCutoffFraction,
              minimumQ >= TPTAntialiasedNonlinearCoreContract.minimumQ,
              minimumQ <= maximumQ,
              maximumQ <= TPTAntialiasedNonlinearCoreContract.maximumQ,
              minimumInputDrive >=
                TPTAntialiasedNonlinearCoreContract.minimumDrive,
              minimumInputDrive <= maximumInputDrive,
              maximumInputDrive <=
                TPTAntialiasedNonlinearCoreContract.maximumDrive,
              minimumOutputDrive >=
                TPTAntialiasedNonlinearCoreContract.minimumDrive,
              minimumOutputDrive <= maximumOutputDrive,
              maximumOutputDrive <=
                TPTAntialiasedNonlinearCoreContract.maximumDrive,
              minimumBandMix >= 0,
              minimumBandMix <= maximumBandMix,
              maximumBandMix <=
                TPTAntialiasedNonlinearCoreContract.maximumBandMix,
              Self.isSampleHash(inputSampleHash),
              Self.isSampleHash(outputSampleHash),
              inputPeak > 0, inputRMS > 0, inputRMS <= inputPeak,
              outputPeak > 0, outputRMS > 0, outputRMS <= outputPeak,
              inputPeak <= Double(Float.greatestFiniteMagnitude),
              outputPeak <= Double(Float.greatestFiniteMagnitude) else {
            return false
        }
        return true
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

package struct AutonomousUpperSpectralRevealEvidence: Codable, Equatable,
        Sendable {
    package let eligible: Bool
    package let active: Bool
    package let sourceScoreEventCount: Int
    package let renderedEventCount: Int
    package let activeEventCount: Int
    package let minimumActiveAperture: Double
    package let maximumActiveAperture: Double
    package let minimumAppliedCutoffHz: Double
    package let maximumAppliedCutoffHz: Double
    package let scoreFingerprint: String
    package let renderFingerprint: String
    package let anchorSampleHash: String
    package let anchorPeak: Double
    package let anchorRMS: Double
    package let bindingValid: Bool
    package let finite: Bool

    package init(_ evidence: UpperSpectralRevealRenderEvidence) {
        eligible = evidence.eligible
        active = evidence.active
        sourceScoreEventCount = evidence.sourceScoreEventCount
        renderedEventCount = evidence.renderedEventCount
        activeEventCount = evidence.activeEventCount
        minimumActiveAperture = evidence.minimumActiveAperture
        maximumActiveAperture = evidence.maximumActiveAperture
        minimumAppliedCutoffHz = evidence.minimumAppliedCutoffHz
        maximumAppliedCutoffHz = evidence.maximumAppliedCutoffHz
        scoreFingerprint = evidence.scoreFingerprint
        renderFingerprint = evidence.renderFingerprint
        anchorSampleHash = evidence.anchorSampleHash
        anchorPeak = evidence.anchorPeak
        anchorRMS = evidence.anchorRMS
        bindingValid = evidence.bindingValid
        finite = evidence.finite
    }

    package var isFinite: Bool {
        finite && [
            minimumActiveAperture, maximumActiveAperture, minimumAppliedCutoffHz,
            maximumAppliedCutoffHz, anchorPeak, anchorRMS,
        ].allSatisfy(\.isFinite)
    }

    package func isComplete(
        architecture: String,
        architectureEventCount: Int,
        sampleRate: Double
    ) -> Bool {
        guard let resolvedArchitecture = InstrumentArchitecture(
            rawValue: architecture
        ), resolvedArchitecture == .resonantMono ||
                resolvedArchitecture == .tonalMotion,
              bindingValid, isFinite,
              sourceScoreEventCount > 0,
              sourceScoreEventCount == renderedEventCount,
              activeEventCount >= 0,
              activeEventCount <= renderedEventCount,
              renderedEventCount <= architectureEventCount,
              renderedEventCount <=
                AutonomousCandidateEvaluationVector.maximumInstrumentEventsPerBar,
              minimumAppliedCutoffHz >=
                TPTAntialiasedNonlinearCoreContract.minimumCutoffHz,
              minimumAppliedCutoffHz <= maximumAppliedCutoffHz,
              sampleRate >=
                QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <=
                QualityQualificationContract.maximumSupportedSampleRate,
              Self.isSampleHash(scoreFingerprint),
              Self.isSampleHash(renderFingerprint),
              Self.isSampleHash(anchorSampleHash),
              anchorPeak > 0, anchorRMS > 0,
              anchorRMS <= anchorPeak else {
            return false
        }
        let maximumCutoffFraction = resolvedArchitecture == .resonantMono
            ? TPTAntialiasedNonlinearCoreContract.maximumCutoffFraction
            : 0.36
        guard maximumAppliedCutoffHz <= sampleRate * maximumCutoffFraction else {
            return false
        }
        if active {
            return eligible && activeEventCount > 0 &&
                minimumActiveAperture >=
                    UpperSpectralRevealArticulation.minimumAperture &&
                minimumActiveAperture <= maximumActiveAperture &&
                maximumActiveAperture < 1
        }
        return activeEventCount == 0 &&
            minimumActiveAperture.bitPattern == 1.0.bitPattern &&
            maximumActiveAperture.bitPattern == 1.0.bitPattern
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
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
    package let nonlinearCore:
        AutonomousTPTAntialiasedNonlinearCoreEvidence?
    package let resonantMonoModulation:
        AutonomousResonantMonoModulationEvidence?
    package let spectralTextureCluster:
        AutonomousSpectralTextureClusterEvidence?
    package let spectralTextureHarmonicTail:
        AutonomousSpectralTextureHarmonicTailEvidence?
    package let indefinitePitch: AutonomousIndefinitePitchEvidence?
    package let tonalEnvelopeExpansion:
        AutonomousTonalEnvelopeExpansionEvidence?
    package let upperSpectralReveal:
        AutonomousUpperSpectralRevealEvidence?

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
        nonlinearCore = evidence.nonlinearCore.map(
            AutonomousTPTAntialiasedNonlinearCoreEvidence.init
        )
        resonantMonoModulation = evidence.resonantMonoModulation.map(
            AutonomousResonantMonoModulationEvidence.init
        )
        spectralTextureCluster = evidence.spectralTextureCluster.map(
            AutonomousSpectralTextureClusterEvidence.init
        )
        spectralTextureHarmonicTail = evidence.spectralTextureHarmonicTail.map(
            AutonomousSpectralTextureHarmonicTailEvidence.init
        )
        indefinitePitch = evidence.indefinitePitch.map(
            AutonomousIndefinitePitchEvidence.init
        )
        tonalEnvelopeExpansion = evidence.tonalEnvelopeExpansion.map(
            AutonomousTonalEnvelopeExpansionEvidence.init
        )
        upperSpectralReveal = evidence.upperSpectralReveal.map(
            AutonomousUpperSpectralRevealEvidence.init
        )
    }

    package var isFinite: Bool {
        finite && peak.isFinite && rms.isFinite &&
            (nonlinearCore?.isFinite ?? true) &&
            (resonantMonoModulation?.isFinite ?? true) &&
            (spectralTextureCluster?.isFinite ?? true) &&
            (spectralTextureHarmonicTail?.isFinite ?? true) &&
            (indefinitePitch?.isFinite ?? true) &&
            (tonalEnvelopeExpansion?.isFinite ?? true) &&
            (upperSpectralReveal?.isFinite ?? true) &&
            assignments.allSatisfy { $0.isFinite }
    }

    package func isComplete(sampleRate: Double) -> Bool {
        let baseComplete = InstrumentArchitecture(rawValue: architecture) != nil &&
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
        guard baseComplete else { return false }
        if architecture == InstrumentArchitecture.resonantMono.rawValue {
            guard let nonlinearCore,
                  nonlinearCore.isComplete(
                    architectureAssignmentCount: assignments.count,
                    architectureEventCount: eventCount,
                    sampleRate: sampleRate
                  ) else { return false }
        } else if nonlinearCore != nil {
            return false
        }
        let hasAcidAssignment = assignments.contains {
            $0.patch == InstrumentPatch.acidThread.rawValue ||
                $0.patch == InstrumentPatch.acidSequence.rawValue
        }
        if hasAcidAssignment {
            guard architecture == InstrumentArchitecture.resonantMono.rawValue,
                  let resonantMonoModulation else { return false }
            guard resonantMonoModulation.isComplete(
                assignments: assignments,
                architectureEventCount: eventCount
            ) else { return false }
        } else if resonantMonoModulation != nil {
            return false
        }
        let hasClusterAssignment = assignments.contains {
            $0.patch == InstrumentPatch.metalVeil.rawValue &&
                $0.use == InstrumentUse.transition.rawValue
        }
        if hasClusterAssignment {
            guard architecture == InstrumentArchitecture.spectralTexture.rawValue,
                  let spectralTextureCluster else { return false }
            guard spectralTextureCluster.isComplete(
                assignments: assignments,
                architectureEventCount: eventCount,
                sampleRate: sampleRate
            ) else { return false }
        } else if spectralTextureCluster != nil {
            return false
        }
        let hasHarmonicTailAssignment = assignments.contains {
            $0.patch == InstrumentPatch.voltageArc.rawValue &&
                $0.use == InstrumentUse.response.rawValue
        }
        if hasHarmonicTailAssignment {
            guard architecture == InstrumentArchitecture.spectralTexture.rawValue,
                  let spectralTextureHarmonicTail else { return false }
            guard spectralTextureHarmonicTail.isComplete(
                assignments: assignments,
                architectureEventCount: eventCount,
                sampleRate: sampleRate
            ) else { return false }
        } else if spectralTextureHarmonicTail != nil {
            return false
        }
        let hasIndefinitePitchAssignment = assignments.contains {
            $0.pitchIdentity == MusicalPitchIdentity.indefinitePitch.rawValue
        }
        if hasIndefinitePitchAssignment {
            guard architecture == InstrumentArchitecture.spectralTexture.rawValue,
                  let indefinitePitch,
                  indefinitePitch.isComplete(
                    assignments: assignments,
                    architectureEventCount: eventCount
                  ) else { return false }
        } else if indefinitePitch != nil {
            return false
        }
        guard architecture == InstrumentArchitecture.tonalMotion.rawValue ||
                tonalEnvelopeExpansion == nil else { return false }
        if architecture == InstrumentArchitecture.tonalMotion.rawValue,
           let tonalEnvelopeExpansion {
            guard assignments.contains(where: {
                $0.use == InstrumentUse.motif.rawValue
            }) else { return false }
            guard tonalEnvelopeExpansion.isComplete(
                architectureEventCount: eventCount,
                sampleRate: sampleRate
            ) else { return false }
        }
        let hasMotifAssignment = assignments.contains {
            $0.use == InstrumentUse.motif.rawValue
        }
        let revealArchitecture = architecture ==
                InstrumentArchitecture.resonantMono.rawValue ||
            architecture == InstrumentArchitecture.tonalMotion.rawValue
        if hasMotifAssignment && revealArchitecture {
            guard let upperSpectralReveal,
                  upperSpectralReveal.isComplete(
                    architecture: architecture,
                    architectureEventCount: eventCount,
                    sampleRate: sampleRate
                  ) else { return false }
        } else if upperSpectralReveal != nil {
            return false
        }
        return true
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

package struct AutonomousTonalEnvelopeExpansionEvidence: Codable, Equatable,
        Sendable {
    package let eligible: Bool
    package let active: Bool
    package let eventCount: Int
    package let relation: String
    package let baseSustain: Double
    package let baseReleaseSeconds: Double
    package let appliedSustain: Double
    package let appliedReleaseSeconds: Double
    package let eventFingerprint: String
    package let sampleHash: String
    package let peak: Double
    package let rms: Double
    package let attackRMS: Double
    package let tailRMS: Double
    package let tailToAttackDB: Double
    package let nonzeroSampleCount: Int
    package let bindingValid: Bool
    package let finite: Bool

    package init(_ evidence: TonalEnvelopeExpansionRenderEvidence) {
        eligible = evidence.eligible
        active = evidence.active
        eventCount = evidence.eventCount
        relation = evidence.relation.rawValue
        baseSustain = evidence.baseSustain
        baseReleaseSeconds = evidence.baseReleaseSeconds
        appliedSustain = evidence.appliedSustain
        appliedReleaseSeconds = evidence.appliedReleaseSeconds
        eventFingerprint = evidence.eventFingerprint
        sampleHash = evidence.sampleHash
        peak = evidence.peak
        rms = evidence.rms
        attackRMS = evidence.attackRMS
        tailRMS = evidence.tailRMS
        tailToAttackDB = evidence.tailToAttackDB
        nonzeroSampleCount = evidence.nonzeroSampleCount
        bindingValid = evidence.bindingValid
        finite = evidence.finite
    }

    package var isFinite: Bool {
        finite && [
            baseSustain, baseReleaseSeconds, appliedSustain,
            appliedReleaseSeconds, peak, rms, attackRMS,
            tailRMS, tailToAttackDB,
        ].allSatisfy { $0.isFinite }
    }

    package func isComplete(architectureEventCount: Int,
                            sampleRate: Double) -> Bool {
        let relationValid = UpperEnvelopeRelation(rawValue: relation) != nil
        guard isFinite, bindingValid, relationValid,
              eventCount >= 0, eventCount <= 1,
              architectureEventCount >= eventCount,
              Self.isSampleHash(eventFingerprint),
              Self.isSampleHash(sampleHash),
              nonzeroSampleCount >= 0,
              nonzeroSampleCount <= Self.barFrames(sampleRate: sampleRate),
              peak >= 0, rms >= 0, rms <= peak,
              attackRMS >= 0, attackRMS <= peak,
              tailRMS >= 0, tailRMS <= peak,
              abs(tailToAttackDB) <= 160 else { return false }
        let expectedTailToAttackDB = attackRMS > 0
            ? 20 * log10(max(1e-12, tailRMS) / attackRMS) : 0
        guard tailToAttackDB == expectedTailToAttackDB else { return false }
        let zeroHash = AutonomousKickSyntaxBarEvidence.zeroSampleHash(
            renderedFrameCount: Self.barFrames(sampleRate: sampleRate)
        )
        if active {
            let expected = TonalEnvelopeExpansionContract.resolve(
                baseSustain: baseSustain,
                baseReleaseSeconds: baseReleaseSeconds,
                relation: .sustainedWash
            )
            return eligible && eventCount == 1 &&
                relation == UpperEnvelopeRelation.sustainedWash.rawValue &&
                baseSustain >= 0 &&
                baseSustain <= TonalEnvelopeExpansionContract.maximumSustain &&
                baseReleaseSeconds > 0 &&
                appliedSustain == expected.sustain &&
                appliedReleaseSeconds == expected.releaseSeconds &&
                peak > 0 && rms > 0 && attackRMS > 0 && tailRMS > 0 &&
                nonzeroSampleCount > 0 && sampleHash != zeroHash
        }
        return eventCount == 0 && relation == UpperEnvelopeRelation.home.rawValue &&
            baseSustain == 0 && baseReleaseSeconds == 0 &&
            appliedSustain == 0 && appliedReleaseSeconds == 0 && peak == 0 &&
            rms == 0 && attackRMS == 0 && tailRMS == 0 &&
            tailToAttackDB == 0 && nonzeroSampleCount == 0 &&
            sampleHash == zeroHash
    }

    private static func barFrames(sampleRate: Double) -> Int {
        guard sampleRate.isFinite, sampleRate > 0 else { return 0 }
        return max(1, Int((240 / AutonomousSessionDirector.bpm * sampleRate).rounded()))
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

/// Compact same-pass proof for one existing clap, open-hat, or metallic score
/// event. The base path is reduced alongside the rendered path so the record
/// can distinguish a truthful attack-preserving clearance envelope from a
/// disconnected score label or a broad gain change.
package struct AutonomousUpperPercussionTailEventEvidence:
        Codable, Equatable, Sendable {
    package let scoreEventIndex: Int
    package let voice: String
    package let step: Int
    package let role: String
    package let body: String
    package let intensity: Double
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

    package init(
        scoreEventIndex: Int,
        voice: String,
        step: Int,
        role: String,
        body: String,
        intensity: Double,
        timingOffsetInSteps: Double,
        relocated: Bool,
        renderedFrameCount: Int,
        attackFrameCount: Int,
        appliedFinalMultiplier: Double,
        baseSampleHash: String,
        renderedSampleHash: String,
        baseAttackSampleHash: String,
        renderedAttackSampleHash: String,
        basePeak: Double,
        renderedPeak: Double,
        baseRMS: Double,
        renderedRMS: Double,
        baseAttackRMS: Double,
        renderedAttackRMS: Double,
        baseTailRMS: Double,
        renderedTailRMS: Double,
        baseTailToAttackDB: Double,
        renderedTailToAttackDB: Double,
        differenceRMS: Double,
        finite: Bool
    ) {
        self.scoreEventIndex = scoreEventIndex
        self.voice = voice
        self.step = step
        self.role = role
        self.body = body
        self.intensity = intensity
        self.timingOffsetInSteps = timingOffsetInSteps
        self.relocated = relocated
        self.renderedFrameCount = renderedFrameCount
        self.attackFrameCount = attackFrameCount
        self.appliedFinalMultiplier = appliedFinalMultiplier
        self.baseSampleHash = baseSampleHash
        self.renderedSampleHash = renderedSampleHash
        self.baseAttackSampleHash = baseAttackSampleHash
        self.renderedAttackSampleHash = renderedAttackSampleHash
        self.basePeak = basePeak
        self.renderedPeak = renderedPeak
        self.baseRMS = baseRMS
        self.renderedRMS = renderedRMS
        self.baseAttackRMS = baseAttackRMS
        self.renderedAttackRMS = renderedAttackRMS
        self.baseTailRMS = baseTailRMS
        self.renderedTailRMS = renderedTailRMS
        self.baseTailToAttackDB = baseTailToAttackDB
        self.renderedTailToAttackDB = renderedTailToAttackDB
        self.differenceRMS = differenceRMS
        self.finite = finite
    }

    package init(_ evidence: UpperPercussionTailRenderEvidence) {
        self.init(
            scoreEventIndex: evidence.scoreEventIndex,
            voice: evidence.voice.rawValue,
            step: evidence.step,
            role: evidence.role.rawValue,
            body: evidence.body.rawValue,
            intensity: evidence.eventIntensity,
            timingOffsetInSteps: evidence.timingOffsetInSteps,
            relocated: evidence.relocated,
            renderedFrameCount: evidence.renderedFrameCount,
            attackFrameCount: evidence.attackFrameCount,
            appliedFinalMultiplier: evidence.appliedFinalMultiplier,
            baseSampleHash: evidence.baseSampleHash,
            renderedSampleHash: evidence.renderedSampleHash,
            baseAttackSampleHash: evidence.baseAttackSampleHash,
            renderedAttackSampleHash: evidence.renderedAttackSampleHash,
            basePeak: evidence.basePeak,
            renderedPeak: evidence.renderedPeak,
            baseRMS: evidence.baseRMS,
            renderedRMS: evidence.renderedRMS,
            baseAttackRMS: evidence.baseAttackRMS,
            renderedAttackRMS: evidence.renderedAttackRMS,
            baseTailRMS: evidence.baseTailRMS,
            renderedTailRMS: evidence.renderedTailRMS,
            baseTailToAttackDB: evidence.baseTailToAttackDB,
            renderedTailToAttackDB: evidence.renderedTailToAttackDB,
            differenceRMS: evidence.differenceRMS,
            finite: evidence.finite
        )
    }

    package var isFinite: Bool {
        finite && [
            intensity, timingOffsetInSteps, appliedFinalMultiplier,
            basePeak, renderedPeak, baseRMS, renderedRMS, baseAttackRMS,
            renderedAttackRMS, baseTailRMS, renderedTailRMS,
            baseTailToAttackDB, renderedTailToAttackDB, differenceRMS,
        ].allSatisfy(\.isFinite)
    }

    package func isComplete(sampleRate: Double) -> Bool {
        guard sampleRate.isFinite,
              (QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate)
                .contains(sampleRate),
              let resolvedVoice = EnsembleVoice(rawValue: voice),
              resolvedVoice == .clap || resolvedVoice == .openHat ||
                resolvedVoice == .metallic,
              let resolvedRole = UpperPercussionTailRole(rawValue: role),
              let resolvedBody = UpperPercussionBody(rawValue: body),
              (0..<(16 * 6)).contains(scoreEventIndex),
              (0..<16).contains(step),
              (0...1).contains(intensity),
              (0...0.24).contains(timingOffsetInSteps),
              renderedFrameCount > 0,
              renderedFrameCount <= Self.maximumFrameCount(
                voice: resolvedVoice,
                sampleRate: sampleRate
              ),
              attackFrameCount == UpperPercussionTailDSPContract.attackFrameCount(
                sampleRate: sampleRate,
                renderedFrameCount: renderedFrameCount
              ),
              attackFrameCount > 0,
              attackFrameCount < renderedFrameCount,
              Self.isSampleHash(baseSampleHash),
              Self.isSampleHash(renderedSampleHash),
              Self.isSampleHash(baseAttackSampleHash),
              Self.isSampleHash(renderedAttackSampleHash),
              basePeak > 0, renderedPeak > 0,
              baseRMS > 0, renderedRMS > 0,
              baseAttackRMS > 0, renderedAttackRMS > 0,
              baseTailRMS > 0, renderedTailRMS > 0,
              baseRMS <= basePeak, renderedRMS <= renderedPeak,
              baseAttackRMS <= basePeak,
              renderedAttackRMS <= renderedPeak,
              baseTailRMS <= basePeak, renderedTailRMS <= renderedPeak,
              differenceRMS >= 0,
              differenceRMS + 1e-12 >= abs(baseRMS - renderedRMS),
              differenceRMS <= baseRMS + renderedRMS + 1e-12,
              baseTailToAttackDB == Self.tailToAttackDB(
                tailRMS: baseTailRMS,
                attackRMS: baseAttackRMS
              ),
              renderedTailToAttackDB == Self.tailToAttackDB(
                tailRMS: renderedTailRMS,
                attackRMS: renderedAttackRMS
              ),
              baseAttackSampleHash == renderedAttackSampleHash,
              baseAttackRMS == renderedAttackRMS,
              isFinite else {
            return false
        }

        guard resolvedVoice == .clap
            ? resolvedBody == .clap || resolvedBody == .snare || resolvedBody == .rim
            : resolvedBody == .native else {
            return false
        }

        switch resolvedRole {
        case .naturalBody:
            return appliedFinalMultiplier == 1 &&
                baseSampleHash == renderedSampleHash &&
                basePeak == renderedPeak && baseRMS == renderedRMS &&
                baseTailRMS == renderedTailRMS &&
                baseTailToAttackDB == renderedTailToAttackDB &&
                differenceRMS.bitPattern == 0
        case .foregroundClearance:
            return appliedFinalMultiplier == Double(
                UpperPercussionTailDSPContract.clearanceFinalMultiplier
            ) && baseSampleHash != renderedSampleHash &&
                renderedPeak <= basePeak && renderedRMS < baseRMS &&
                renderedTailRMS < baseTailRMS &&
                renderedTailToAttackDB < baseTailToAttackDB &&
                differenceRMS > 0
        }
    }

    private static func maximumFrameCount(
        voice: EnsembleVoice,
        sampleRate: Double
    ) -> Int {
        let duration = switch voice {
        case .clap: 0.16
        case .openHat: 0.19
        case .metallic: 0.065
        default: 0.0
        }
        return max(0, Int(sampleRate * duration))
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

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// One bounded record per bar replays the score-owned contextual policy and
/// retains the exact event bijection. Empty bars remain explicit evidence.
package struct AutonomousUpperPercussionTailBarEvidence:
        Codable, Equatable, Sendable {
    package let bar: Int
    package let focusRole: String
    package let intentionalPileup: Bool
    package let sourceScoreEventCount: Int
    package let sourceRenderEventCount: Int
    package let renderPassesMatch: Bool
    package let bindingValid: Bool
    package let events: [AutonomousUpperPercussionTailEventEvidence]

    package init(
        bar: Int,
        focusRole: String,
        intentionalPileup: Bool,
        sourceScoreEventCount: Int,
        sourceRenderEventCount: Int,
        renderPassesMatch: Bool,
        bindingValid: Bool,
        events: [AutonomousUpperPercussionTailEventEvidence]
    ) {
        self.bar = bar
        self.focusRole = focusRole
        self.intentionalPileup = intentionalPileup
        self.sourceScoreEventCount = sourceScoreEventCount
        self.sourceRenderEventCount = sourceRenderEventCount
        self.renderPassesMatch = renderPassesMatch
        self.bindingValid = bindingValid
        self.events = Array(events.prefix(
            AutonomousCandidateEvaluationVector
                .maximumUpperPercussionTailEventsPerBar
        ))
    }

    package var isFinite: Bool { events.allSatisfy(\.isFinite) }

    package func isComplete(
        sampleRate: Double,
        phraseKind: AutonomousPhraseKind
    ) -> Bool {
        guard bar >= 0,
              let resolvedFocus = PerformanceRole(rawValue: focusRole),
              sourceScoreEventCount >= 0,
              sourceScoreEventCount <= AutonomousCandidateEvaluationVector
                .maximumUpperPercussionTailEventsPerBar,
              sourceRenderEventCount == sourceScoreEventCount,
              events.count == sourceScoreEventCount,
              events.map(\.scoreEventIndex) ==
                events.map(\.scoreEventIndex).sorted(),
              Set(events.map(\.scoreEventIndex)).count == events.count,
              renderPassesMatch, bindingValid,
              events.allSatisfy({ $0.isComplete(sampleRate: sampleRate) }) else {
            return false
        }
        let expectedRole: UpperPercussionTailRole =
            phraseKind != .identityReturn &&
                resolvedFocus != .percussion && !intentionalPileup ?
                .foregroundClearance : .naturalBody
        return events.allSatisfy { $0.role == expectedRole.rawValue }
    }
}

/// Compact same-pass evidence for one score-owned modal-foundation strike.
/// It retains no excitation or output PCM.
package struct AutonomousModalPercussionEventEvidence:
        Codable, Equatable, Sendable {
    package let scoreEventIndex: Int
    package let step: Int
    package let use: String
    package let modalIdentity: String
    package let modalDegree: Int
    package let octave: Int
    package let requestedFundamentalHz: Double
    package let appliedFundamentalHz: Double
    package let excitation: Double
    package let damping: Double
    package let brightness: Double
    package let inharmonicity: Double
    package let intensity: Double
    package let modeCount: Int
    package let modeRatioFingerprint: String
    package let minimumModeFrequencyHz: Double
    package let maximumModeFrequencyHz: Double
    package let maximumPoleRadius: Double
    package let excitationFingerprint: String
    package let drySampleHash: String
    package let renderedFrameCount: Int
    package let nonzeroSampleCount: Int
    package let peak: Double
    package let rms: Double
    package let crestFactor: Double
    package let attackRMS: Double
    package let bodyRMS: Double
    package let tailRMS: Double
    package let tailToBodyDB: Double
    package let spectralCentroidHz: Double
    package let incomingVoiceStateFingerprint: String
    package let outgoingVoiceStateFingerprint: String
    package let finite: Bool
    package let stable: Bool
    package let capacityValid: Bool
    package let scoreBindingValid: Bool
    package let routeBindingValid: Bool

    package init(
        scoreEventIndex: Int,
        step: Int,
        use: String,
        modalIdentity: String,
        modalDegree: Int,
        octave: Int,
        requestedFundamentalHz: Double,
        appliedFundamentalHz: Double,
        excitation: Double,
        damping: Double,
        brightness: Double,
        inharmonicity: Double,
        intensity: Double,
        modeCount: Int,
        modeRatioFingerprint: String,
        minimumModeFrequencyHz: Double,
        maximumModeFrequencyHz: Double,
        maximumPoleRadius: Double,
        excitationFingerprint: String,
        drySampleHash: String,
        renderedFrameCount: Int,
        nonzeroSampleCount: Int,
        peak: Double,
        rms: Double,
        crestFactor: Double,
        attackRMS: Double,
        bodyRMS: Double,
        tailRMS: Double,
        tailToBodyDB: Double,
        spectralCentroidHz: Double,
        incomingVoiceStateFingerprint: String,
        outgoingVoiceStateFingerprint: String,
        finite: Bool,
        stable: Bool,
        capacityValid: Bool,
        scoreBindingValid: Bool,
        routeBindingValid: Bool
    ) {
        self.scoreEventIndex = scoreEventIndex
        self.step = step
        self.use = use
        self.modalIdentity = modalIdentity
        self.modalDegree = modalDegree
        self.octave = octave
        self.requestedFundamentalHz = requestedFundamentalHz
        self.appliedFundamentalHz = appliedFundamentalHz
        self.excitation = excitation
        self.damping = damping
        self.brightness = brightness
        self.inharmonicity = inharmonicity
        self.intensity = intensity
        self.modeCount = modeCount
        self.modeRatioFingerprint = modeRatioFingerprint
        self.minimumModeFrequencyHz = minimumModeFrequencyHz
        self.maximumModeFrequencyHz = maximumModeFrequencyHz
        self.maximumPoleRadius = maximumPoleRadius
        self.excitationFingerprint = excitationFingerprint
        self.drySampleHash = drySampleHash
        self.renderedFrameCount = renderedFrameCount
        self.nonzeroSampleCount = nonzeroSampleCount
        self.peak = peak
        self.rms = rms
        self.crestFactor = crestFactor
        self.attackRMS = attackRMS
        self.bodyRMS = bodyRMS
        self.tailRMS = tailRMS
        self.tailToBodyDB = tailToBodyDB
        self.spectralCentroidHz = spectralCentroidHz
        self.incomingVoiceStateFingerprint = incomingVoiceStateFingerprint
        self.outgoingVoiceStateFingerprint = outgoingVoiceStateFingerprint
        self.finite = finite
        self.stable = stable
        self.capacityValid = capacityValid
        self.scoreBindingValid = scoreBindingValid
        self.routeBindingValid = routeBindingValid
    }

    package var isFinite: Bool {
        finite && [
            requestedFundamentalHz, appliedFundamentalHz, excitation, damping,
            brightness, inharmonicity, intensity, minimumModeFrequencyHz,
            maximumModeFrequencyHz, maximumPoleRadius, peak, rms, crestFactor,
            attackRMS, bodyRMS, tailRMS, tailToBodyDB, spectralCentroidHz,
        ].allSatisfy(\.isFinite)
    }

    package func isComplete(sampleRate: Double) -> Bool {
        let expectedFrames = max(1, Int((
            240 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded()))
        return sampleRate.isFinite && sampleRate > 0 &&
            ModalPercussionUse(rawValue: use) == .foundationCompanion &&
            ModalIdentity(rawValue: modalIdentity) != nil &&
            (0..<(16 * 6)).contains(scoreEventIndex) &&
            (0..<16).contains(step) &&
            (0..<12).contains(modalDegree) &&
            (-2...6).contains(octave) &&
            (48...196).contains(requestedFundamentalHz) &&
            appliedFundamentalHz == requestedFundamentalHz &&
            appliedFundamentalHz > 0 &&
            appliedFundamentalHz < 0.9 * sampleRate * 0.5 &&
            (0...1).contains(excitation) && (0...1).contains(damping) &&
            (0...1).contains(brightness) &&
            (0...0.12).contains(inharmonicity) &&
            (0...1).contains(intensity) &&
            modeCount == ModalPercussionVoice.modeCount &&
            Self.isFingerprint(modeRatioFingerprint) &&
            minimumModeFrequencyHz >= appliedFundamentalHz &&
            maximumModeFrequencyHz >= minimumModeFrequencyHz &&
            maximumModeFrequencyHz < 0.9 * sampleRate * 0.5 &&
            maximumPoleRadius > 0 && maximumPoleRadius < 1 &&
            Self.isFingerprint(excitationFingerprint) &&
            Self.isFingerprint(drySampleHash) &&
            renderedFrameCount == expectedFrames &&
            nonzeroSampleCount > 0 &&
            nonzeroSampleCount <= renderedFrameCount &&
            peak > 0 && peak <= 1 && rms > 0 && rms <= peak &&
            crestFactor >= 1 && attackRMS >= 0 && attackRMS <= 1 &&
            bodyRMS >= 0 && bodyRMS <= 1 && tailRMS >= 0 && tailRMS <= 1 &&
            (-120...120).contains(tailToBodyDB) &&
            (0...(sampleRate / 2)).contains(spectralCentroidHz) &&
            Self.isFingerprint(incomingVoiceStateFingerprint) &&
            Self.isFingerprint(outgoingVoiceStateFingerprint) &&
            stable && capacityValid && scoreBindingValid && routeBindingValid
    }

    private static func isFingerprint(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Every candidate bar owns one modal record, including explicit empty and
/// continuation-only bars.
package struct AutonomousModalPercussionBarEvidence:
        Codable, Equatable, Sendable {
    package let bar: Int
    package let sourceScoreEventCount: Int
    package let sourceRenderEventCount: Int
    package let use: String
    package let incomingStateFingerprint: String
    package let outgoingStateFingerprint: String
    package let dryBarSampleHash: String
    package let activeIncomingVoiceCount: Int
    package let activeOutgoingVoiceCount: Int
    package let continuationRendered: Bool
    package let renderPassesMatch: Bool
    package let foundationRoutingValid: Bool
    package let events: [AutonomousModalPercussionEventEvidence]

    package init(
        bar: Int,
        sourceScoreEventCount: Int,
        sourceRenderEventCount: Int,
        use: String,
        incomingStateFingerprint: String,
        outgoingStateFingerprint: String,
        dryBarSampleHash: String,
        activeIncomingVoiceCount: Int,
        activeOutgoingVoiceCount: Int,
        continuationRendered: Bool,
        renderPassesMatch: Bool,
        foundationRoutingValid: Bool,
        events: [AutonomousModalPercussionEventEvidence]
    ) {
        self.bar = bar
        self.sourceScoreEventCount = sourceScoreEventCount
        self.sourceRenderEventCount = sourceRenderEventCount
        self.use = use
        self.incomingStateFingerprint = incomingStateFingerprint
        self.outgoingStateFingerprint = outgoingStateFingerprint
        self.dryBarSampleHash = dryBarSampleHash
        self.activeIncomingVoiceCount = activeIncomingVoiceCount
        self.activeOutgoingVoiceCount = activeOutgoingVoiceCount
        self.continuationRendered = continuationRendered
        self.renderPassesMatch = renderPassesMatch
        self.foundationRoutingValid = foundationRoutingValid
        self.events = Array(events.prefix(
            AutonomousCandidateEvaluationVector.maximumModalPercussionEventsPerBar
        ))
    }

    package var isFinite: Bool { events.allSatisfy { $0.isFinite } }

    package func isComplete(sampleRate: Double) -> Bool {
        let expectedFrames = max(1, Int((
            240 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded()))
        let neutralStateIsCanonical = sourceScoreEventCount != 0 ||
            activeIncomingVoiceCount != 0 || activeOutgoingVoiceCount != 0 || (
                incomingStateFingerprint == outgoingStateFingerprint &&
                    dryBarSampleHash == ExactPCMFingerprint.mono(
                        [Float](repeating: 0, count: expectedFrames)
                    )
            )
        return bar >= 0 &&
            ModalPercussionUse(rawValue: use) == .foundationCompanion &&
            sourceScoreEventCount >= 0 &&
            sourceScoreEventCount <=
                AutonomousCandidateEvaluationVector.maximumModalPercussionEventsPerBar &&
            sourceRenderEventCount == sourceScoreEventCount &&
            events.count == sourceScoreEventCount &&
            events.map(\.scoreEventIndex) ==
                events.map(\.scoreEventIndex).sorted() &&
            Set(events.map(\.scoreEventIndex)).count == events.count &&
            Self.isFingerprint(incomingStateFingerprint) &&
            Self.isFingerprint(outgoingStateFingerprint) &&
            Self.isFingerprint(dryBarSampleHash) &&
            (0...ModalPercussionVoice.voiceCapacity)
                .contains(activeIncomingVoiceCount) &&
            (0...ModalPercussionVoice.voiceCapacity)
                .contains(activeOutgoingVoiceCount) &&
            continuationRendered == (activeIncomingVoiceCount > 0) &&
            neutralStateIsCanonical && renderPassesMatch &&
            foundationRoutingValid &&
            events.allSatisfy {
                $0.use == use && $0.isComplete(sampleRate: sampleRate)
            }
    }

    private static func isFingerprint(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
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

    package func isComplete(sampleRate: Double) -> Bool {
        let revealCount = architectures.reduce(into: 0) {
            if $1.upperSpectralReveal != nil { $0 += 1 }
        }
        return bar >= 0 && sourceArchitectureCount == architectures.count &&
            architectures.count <=
                AutonomousCandidateEvaluationVector.maximumInstrumentArchitecturesPerBar &&
            revealCount <= 1 &&
            architectures.allSatisfy { $0.isComplete(sampleRate: sampleRate) } &&
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

    package var tonalEnvelopeExpansionEligible: Bool {
        architectures.first {
            $0.architecture == InstrumentArchitecture.tonalMotion.rawValue
        }?.tonalEnvelopeExpansion?.eligible ?? false
    }

    package var tonalEnvelopeExpansionActive: Bool {
        architectures.first {
            $0.architecture == InstrumentArchitecture.tonalMotion.rawValue
        }?.tonalEnvelopeExpansion?.active ?? false
    }

    package var spectralRevealEligible: Bool {
        architectures.compactMap(\.upperSpectralReveal).contains {
            $0.eligible
        }
    }

    package var spectralRevealActive: Bool {
        architectures.compactMap(\.upperSpectralReveal).contains {
            $0.active
        }
    }
}

/// One compact record per rendered bar binds the score-owned percussion input
/// and output gates to the exact protected-rhythm return. The gated source and
/// return PCM are reduced to hashes and scalars before scheduling.
package struct AutonomousPercussionEchoTextureBarEvidence: Codable, Equatable,
        Sendable {
    package let bar: Int
    package let performanceCharacter: String
    package let arrangementGesture: String
    package let kickSyntaxRole: String
    package let active: Bool
    package let relation: String
    package let eligibleSourceStepMask: UInt16
    package let inputStep: Int
    package let outputStartStep: Int
    package let outputEndStep: Int
    package let renderedFrameCount: Int
    package let inputWindowFrameCount: Int
    package let outputWindowFrameCount: Int
    package let delayFrameCount: Int
    package let transitionFrameCount: Int
    package let inputSampleHash: String
    package let returnSampleHash: String
    package let inputPeak: Double
    package let inputRMS: Double
    package let returnPeak: Double
    package let returnRMS: Double
    package let earlyOutputRMS: Double
    package let lateOutputRMS: Double
    package let lateToEarlyDB: Double
    package let inputNonzeroSampleCount: Int
    package let returnNonzeroSampleCount: Int
    package let outOfWindowNonzeroSampleCount: Int
    package let firstOutputSampleBitPattern: UInt32
    package let lastOutputSampleBitPattern: UInt32
    package let renderPassesMatch: Bool
    package let bindingValid: Bool
    package let finite: Bool

    package init(
        _ evidence: PercussionEchoTextureRenderEvidence,
        bar: Int,
        performanceCharacter: PerformanceCharacter,
        arrangementGesture: ArrangementGesture,
        kickSyntaxRole: KickSyntaxRole,
        eligibleSourceStepMask: UInt16,
        renderPassesMatch: Bool,
        bindingValid: Bool
    ) {
        self.bar = bar
        self.performanceCharacter = performanceCharacter.rawValue
        self.arrangementGesture = arrangementGesture.rawValue
        self.kickSyntaxRole = kickSyntaxRole.rawValue
        active = evidence.active
        relation = evidence.relation?.rawValue ?? ""
        self.eligibleSourceStepMask = eligibleSourceStepMask
        inputStep = evidence.inputStep
        outputStartStep = evidence.outputStartStep
        outputEndStep = evidence.outputEndStep
        renderedFrameCount = evidence.renderedFrameCount
        inputWindowFrameCount = evidence.inputWindowFrameCount
        outputWindowFrameCount = evidence.outputWindowFrameCount
        delayFrameCount = evidence.delayFrameCount
        transitionFrameCount = evidence.transitionFrameCount
        inputSampleHash = evidence.inputSampleHash
        returnSampleHash = evidence.returnSampleHash
        inputPeak = evidence.inputPeak
        inputRMS = evidence.inputRMS
        returnPeak = evidence.returnPeak
        returnRMS = evidence.returnRMS
        earlyOutputRMS = evidence.earlyOutputRMS
        lateOutputRMS = evidence.lateOutputRMS
        lateToEarlyDB = evidence.lateToEarlyDB
        inputNonzeroSampleCount = evidence.inputNonzeroSampleCount
        returnNonzeroSampleCount = evidence.returnNonzeroSampleCount
        outOfWindowNonzeroSampleCount = evidence.outOfWindowNonzeroSampleCount
        firstOutputSampleBitPattern = evidence.firstOutputSampleBitPattern
        lastOutputSampleBitPattern = evidence.lastOutputSampleBitPattern
        self.renderPassesMatch = renderPassesMatch
        self.bindingValid = bindingValid
        finite = evidence.finite
    }

    package static func neutral(
        bar: Int,
        sampleRate: Double,
        performanceCharacter: PerformanceCharacter = .hypnoticLock,
        arrangementGesture: ArrangementGesture = .steady
    ) -> Self {
        let frameCount = barFrameCount(sampleRate: sampleRate)
        let evidence = PercussionEchoTextureRenderEvidence(
            active: false,
            relation: nil,
            bpm: AutonomousSessionDirector.bpm,
            sampleRate: sampleRate,
            inputStep: -1,
            outputStartStep: -1,
            outputEndStep: -1,
            renderedFrameCount: frameCount,
            inputWindowFrameCount: 0,
            outputWindowFrameCount: 0,
            delayFrameCount: 0,
            transitionFrameCount: 0,
            inputSampleHash: AutonomousKickSyntaxBarEvidence.zeroSampleHash(
                renderedFrameCount: 0
            ),
            returnSampleHash: AutonomousKickSyntaxBarEvidence.zeroSampleHash(
                renderedFrameCount: frameCount
            ),
            inputPeak: 0,
            inputRMS: 0,
            returnPeak: 0,
            returnRMS: 0,
            earlyOutputRMS: 0,
            lateOutputRMS: 0,
            lateToEarlyDB: 0,
            inputNonzeroSampleCount: 0,
            returnNonzeroSampleCount: 0,
            outOfWindowNonzeroSampleCount: 0,
            firstOutputSampleBitPattern: 0,
            lastOutputSampleBitPattern: 0,
            finite: sampleRate.isFinite && frameCount > 0
        )
        return Self(
            evidence,
            bar: bar,
            performanceCharacter: performanceCharacter,
            arrangementGesture: arrangementGesture,
            kickSyntaxRole: .grounded,
            eligibleSourceStepMask: 0,
            renderPassesMatch: true,
            bindingValid: true
        )
    }

    package var isFinite: Bool {
        finite && [
            inputPeak, inputRMS, returnPeak, returnRMS,
            earlyOutputRMS, lateOutputRMS, lateToEarlyDB,
        ].allSatisfy(\.isFinite)
    }

    package func normalRelation(
        phraseKind: AutonomousPhraseKind
    ) -> PercussionEchoTextureRelation? {
        if phraseKind == .contrast &&
            performanceCharacter == PerformanceCharacter.brokenSuspension.rawValue &&
            arrangementGesture == ArrangementGesture.gearShift.rawValue &&
            kickSyntaxRole == KickSyntaxRole.grounded.rawValue &&
            eligibleSourceStepMask != 0 {
            return .gatedEcho
        }
        let macroPosition = ((bar % 16) + 16) % 16
        if phraseKind == .energyRelease,
           (performanceCharacter == PerformanceCharacter.peakDrive.rawValue ||
            performanceCharacter == PerformanceCharacter.acidPressure.rawValue),
           arrangementGesture == ArrangementGesture.steady.rawValue,
           kickSyntaxRole == KickSyntaxRole.withheld.rawValue,
           macroPosition == PercussionEchoTextureResolver
            .anticipationSwellMacroPosition,
           eligibleSourceStepMask != 0 {
            return .anticipationSwell
        }
        return nil
    }

    package func isComplete(
        sampleRate: Double,
        phraseKind: AutonomousPhraseKind
    ) -> Bool {
        guard bar >= 0,
              PerformanceCharacter(rawValue: performanceCharacter) != nil,
              ArrangementGesture(rawValue: arrangementGesture) != nil,
              KickSyntaxRole(rawValue: kickSyntaxRole) != nil,
              sampleRate.isFinite,
              sampleRate >= QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <= QualityQualificationContract.maximumSupportedSampleRate,
              renderedFrameCount == Self.barFrameCount(sampleRate: sampleRate),
              eligibleSourceStepMask.nonzeroBitCount <= 8,
              eligibleSourceStepMask & 0xff00 == 0,
              Self.isSampleHash(inputSampleHash),
              Self.isSampleHash(returnSampleHash),
              inputPeak >= 0, inputRMS >= 0, inputRMS <= inputPeak,
              returnPeak >= 0, returnRMS >= 0, returnRMS <= returnPeak,
              earlyOutputRMS >= 0, earlyOutputRMS <= returnPeak,
              lateOutputRMS >= 0, lateOutputRMS <= returnPeak,
              (-120...120).contains(lateToEarlyDB),
              inputPeak <= Double(Float.greatestFiniteMagnitude),
              returnPeak <= Double(Float.greatestFiniteMagnitude),
              (0...renderedFrameCount).contains(inputNonzeroSampleCount),
              (0...renderedFrameCount).contains(returnNonzeroSampleCount),
              (0...renderedFrameCount).contains(outOfWindowNonzeroSampleCount),
              renderPassesMatch, bindingValid, isFinite,
              active == (normalRelation(phraseKind: phraseKind) != nil) else {
            return false
        }

        if !active {
            return relation.isEmpty && inputStep == -1 && outputStartStep == -1 &&
                outputEndStep == -1 && inputWindowFrameCount == 0 &&
                outputWindowFrameCount == 0 && delayFrameCount == 0 &&
                transitionFrameCount == 0 && inputPeak.bitPattern == 0 &&
                inputRMS.bitPattern == 0 && returnPeak.bitPattern == 0 &&
                returnRMS.bitPattern == 0 && earlyOutputRMS.bitPattern == 0 &&
                lateOutputRMS.bitPattern == 0 && lateToEarlyDB.bitPattern == 0 &&
                inputNonzeroSampleCount == 0 &&
                returnNonzeroSampleCount == 0 &&
                outOfWindowNonzeroSampleCount == 0 &&
                firstOutputSampleBitPattern & 0x7fff_ffff == 0 &&
                lastOutputSampleBitPattern & 0x7fff_ffff == 0 &&
                inputSampleHash == AutonomousKickSyntaxBarEvidence.zeroSampleHash(
                    renderedFrameCount: 0
                ) && returnSampleHash ==
                    AutonomousKickSyntaxBarEvidence.zeroSampleHash(
                        renderedFrameCount: renderedFrameCount
                    )
        }

        guard let expectedRelation = normalRelation(phraseKind: phraseKind),
              relation == expectedRelation.rawValue else {
            return false
        }
        let expectedInputStep = eligibleSourceStepMask.trailingZeroBitCount
        guard inputStep == expectedInputStep,
              inputStep <= PercussionEchoTextureResolver.latestInputStep else {
            return false
        }
        let expectedOutputStartStep: Int
        let expectedOutputEndStep: Int
        switch expectedRelation {
        case .gatedEcho:
            expectedOutputStartStep = inputStep +
                PercussionEchoTextureResolver.outputDelayInSteps
            expectedOutputEndStep = expectedOutputStartStep +
                PercussionEchoTextureResolver.outputWindowLengthInSteps
        case .anticipationSwell:
            expectedOutputStartStep = inputStep +
                PercussionEchoTextureResolver.inputWindowLengthInSteps
            expectedOutputEndStep = PercussionEchoTextureResolver
                .anticipationSwellOutputEndStep
        }
        guard outputStartStep == expectedOutputStartStep,
              outputEndStep == expectedOutputEndStep,
              outputEndStep <= 16 else {
            return false
        }
        let expectedInputStart = Self.frame(
            step: inputStep,
            renderedFrameCount: renderedFrameCount
        )
        let expectedInputEnd = Self.frame(
            step: inputStep + PercussionEchoTextureResolver.inputWindowLengthInSteps,
            renderedFrameCount: renderedFrameCount
        )
        let expectedOutputStart = Self.frame(
            step: outputStartStep,
            renderedFrameCount: renderedFrameCount
        )
        let expectedOutputEnd = Self.frame(
            step: outputEndStep,
            renderedFrameCount: renderedFrameCount
        )
        let zeroReturnHash = AutonomousKickSyntaxBarEvidence.zeroSampleHash(
            renderedFrameCount: renderedFrameCount
        )
        let computedRiseDB: Double
        if lateOutputRMS > 0, earlyOutputRMS > 0 {
            computedRiseDB = min(120, max(-120,
                20 * (log10(lateOutputRMS) - log10(earlyOutputRMS))
            ))
        } else if lateOutputRMS > 0 {
            computedRiseDB = 120
        } else {
            computedRiseDB = 0
        }
        let riseIsValid = expectedRelation == .gatedEcho ||
            (earlyOutputRMS > 0 && lateOutputRMS > earlyOutputRMS &&
             lateToEarlyDB >= PercussionEchoTextureResolver
                .minimumAnticipationRiseDB)
        return inputWindowFrameCount == expectedInputEnd - expectedInputStart &&
            outputWindowFrameCount == expectedOutputEnd - expectedOutputStart &&
            delayFrameCount == max(
                1,
                Int((Double(renderedFrameCount) / 16).rounded())
            ) && transitionFrameCount ==
                PercussionEchoTextureVoice.transitionFrameCount(
                    sampleRate: sampleRate
                ) && inputPeak > 0 && inputRMS > 0 && returnPeak > 0 &&
            returnRMS > 0 && inputNonzeroSampleCount > 0 &&
            returnNonzeroSampleCount > 0 && outOfWindowNonzeroSampleCount == 0 &&
            firstOutputSampleBitPattern & 0x7fff_ffff == 0 &&
            lastOutputSampleBitPattern & 0x7fff_ffff == 0 &&
            lateToEarlyDB == computedRiseDB && riseIsValid &&
            inputSampleHash != AutonomousKickSyntaxBarEvidence.zeroSampleHash(
                renderedFrameCount: inputWindowFrameCount
            ) && returnSampleHash != zeroReturnHash
    }

    private static func barFrameCount(sampleRate: Double) -> Int {
        Int((240.0 / AutonomousSessionDirector.bpm * sampleRate).rounded())
    }

    private static func frame(step: Int, renderedFrameCount: Int) -> Int {
        Int((Double(step) * Double(renderedFrameCount) / 16).rounded())
    }

    private static func isSampleHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// One bounded score-to-PCM record for the unified phrase-composition layer.
/// Harmonic planning stays in Core; only reduced renderer consequences cross
/// the preparation boundary.
private enum PhraseCompositionArpeggiatorPitchFingerprint {
    static func make(_ pitches: [(step: Int, frequency: Double)]) -> String {
        var sink = StreamingFNV1a()
        sink.domain("phrase-composition-arpeggiator-pitches.typed.v1")
        sink.collection(pitches.count)
        for pitch in pitches {
            sink.int(pitch.step)
            sink.double(pitch.frequency)
        }
        return fixedWidthFingerprintHex(sink.value)
    }
}

package struct AutonomousPhraseCompositionBarEvidence: Codable, Equatable,
        Sendable {
    package let bar: Int
    package let localBar: Int
    package let phraseLength: Int
    package let section: String
    package let arrangementGesture: String
    package let sliceActive: Bool
    package let sliceTriggerCount: Int
    package let sliceReverseTriggerCount: Int
    package let sliceMinimumRate: Double
    package let sliceMaximumRate: Double
    package let sliceSourceKind: String
    package let sliceTexture: String
    package let sliceTextureSeedFingerprint: String
    package let sliceGrainCount: Int
    package let sliceGrainLengthFrames: Int
    package let sliceGrainHopFrames: Int
    package let sliceGrainPositionHash: String
    package let sliceSourceHash: String
    package let sliceOutputHash: String
    package let sliceOutputRMS: Double
    package let arpeggiatorActive: Bool
    package let arpeggiatorDirection: String
    package let arpeggiatorRateInSteps: Int
    package let arpeggiatorOctaveSpan: Int
    package let arpeggiatorStepCount: Int
    package let arpeggiatorScorePitchFingerprint: String
    package let arpeggiatorRenderPitchFingerprint: String
    package let padActive: Bool
    package let padFunction: String
    package let padHarmonicDisclosureStage: String
    package let padVoiceCount: Int
    package let padCommonToneCount: Int
    package let padTotalMovement: Int
    package let padMaximumLeap: Int
    package let padRhythmicModulationRelation: String
    package let padRhythmicModulationPhaseOffset: Int
    package let padRhythmicModulationPatternFingerprint: String
    package let padMinimumFilterScale: Double
    package let padMaximumFilterScale: Double
    package let padMinimumSpatialSendScale: Double
    package let padMaximumSpatialSendScale: Double
    package let padMinimumAmplitudeGateGain: Double
    package let padMaximumAmplitudeGateGain: Double
    package let padAmplitudeGateTransitionFrameCount: Int
    package let padAmplitudeGateOpenFrameCount: Int
    package let padAmplitudeGateClosedFrameCount: Int
    package let padPreAmplitudeGateOutputSampleHash: String
    package let padPreAmplitudeGateSpatialSendSampleHash: String
    package let padAmplitudeGateDifferenceRMS: Double
    package let padSpatialAmplitudeGateDifferenceRMS: Double
    package let padAmplitudeGateClosedOutputRMS: Double
    package let padAmplitudeGateClosedSpatialSendRMS: Double
    package let padFilterModulationDifferenceRMS: Double
    package let padSpatialSendDifferenceRMS: Double
    package let padSpatialSendSampleHash: String
    package let padSpatialSendRMS: Double
    package let padSampleHash: String
    package let padRMS: Double
    package let padPeak: Double
    package let renderPassesMatch: Bool
    package let bindingValid: Bool
    package let finite: Bool

    package init(block: RenderBlock) {
        let composition = block.synthPerformance.composition
        let slice = block.audioSliceRenderEvidence
        let arpeggiator = composition.arpeggiator
        let pad = composition.padVoicing
        let padRender = block.polyphonicPadRenderEvidence
        let scorePitches = arpeggiator?.steps.map { step in
            (step: step.onsetStep,
             frequency: block.synthWorld.rootFrequency * step.frequencyRatio)
        } ?? []
        let renderedAnchors = block.upperNoteRenderEvidence
            .filter { $0.role == .anchor }
            .sorted { lhs, rhs in lhs.onsetFrame < rhs.onsetFrame }
        let renderPitches = zip(scorePitches, renderedAnchors).map {
            (step: $0.0.step, frequency: $0.1.requestedStartFrequency)
        }
        bar = block.bar
        localBar = block.resolvedPerformance.performance.localBar
        phraseLength = block.resolvedPerformance.performance.phraseLength
        section = block.resolvedPerformance.performance.section.rawValue
        arrangementGesture = block.resolvedPerformance.arrangementGesture.rawValue
        sliceActive = slice.active
        sliceTriggerCount = slice.triggerCount
        sliceReverseTriggerCount = slice.reverseTriggerCount
        sliceMinimumRate = slice.minimumPlaybackRate
        sliceMaximumRate = slice.maximumPlaybackRate
        sliceSourceKind = slice.sourceKind?.rawValue ?? ""
        sliceTexture = slice.texture?.rawValue ?? ""
        sliceTextureSeedFingerprint = slice.textureSeedFingerprint
        sliceGrainCount = slice.grainCount
        sliceGrainLengthFrames = slice.grainLengthFrames
        sliceGrainHopFrames = slice.grainHopFrames
        sliceGrainPositionHash = slice.grainSourcePositionHash
        sliceSourceHash = slice.sourceSampleHash
        sliceOutputHash = slice.outputSampleHash
        sliceOutputRMS = slice.outputRMS
        arpeggiatorActive = arpeggiator != nil
        arpeggiatorDirection = arpeggiator?.direction.rawValue ?? ""
        arpeggiatorRateInSteps = arpeggiator?.rateInSteps ?? 0
        arpeggiatorOctaveSpan = arpeggiator?.octaveSpan ?? 0
        arpeggiatorStepCount = arpeggiator?.steps.count ?? 0
        arpeggiatorScorePitchFingerprint = arpeggiator == nil ? "" :
            PhraseCompositionArpeggiatorPitchFingerprint.make(scorePitches)
        arpeggiatorRenderPitchFingerprint = arpeggiator == nil ? "" :
            PhraseCompositionArpeggiatorPitchFingerprint.make(renderPitches)
        padActive = padRender.active
        padFunction = pad?.function.rawValue ?? ""
        padHarmonicDisclosureStage =
            pad?.harmonicDisclosureStage.rawValue ?? ""
        padVoiceCount = padRender.voiceCount
        padCommonToneCount = pad?.commonToneCount ?? 0
        padTotalMovement = pad?.totalMovementInSemitones ?? 0
        padMaximumLeap = pad?.maximumLeapInSemitones ?? 0
        padRhythmicModulationRelation = padRender.active
            ? padRender.rhythmicModulationRelation.rawValue : ""
        padRhythmicModulationPhaseOffset = padRender.active
            ? padRender.rhythmicModulationPhaseOffset : 0
        padRhythmicModulationPatternFingerprint = padRender.active
            ? padRender.rhythmicModulationPatternFingerprint : ""
        padMinimumFilterScale = padRender.minimumFilterScale
        padMaximumFilterScale = padRender.maximumFilterScale
        padMinimumSpatialSendScale = padRender.minimumSpatialSendScale
        padMaximumSpatialSendScale = padRender.maximumSpatialSendScale
        padMinimumAmplitudeGateGain = padRender.minimumAmplitudeGateGain
        padMaximumAmplitudeGateGain = padRender.maximumAmplitudeGateGain
        padAmplitudeGateTransitionFrameCount =
            padRender.amplitudeGateTransitionFrameCount
        padAmplitudeGateOpenFrameCount = padRender.amplitudeGateOpenFrameCount
        padAmplitudeGateClosedFrameCount =
            padRender.amplitudeGateClosedFrameCount
        padPreAmplitudeGateOutputSampleHash =
            padRender.preAmplitudeGateOutputSampleHash
        padPreAmplitudeGateSpatialSendSampleHash =
            padRender.preAmplitudeGateSpatialSendSampleHash
        padAmplitudeGateDifferenceRMS = padRender.amplitudeGateDifferenceRMS
        padSpatialAmplitudeGateDifferenceRMS =
            padRender.spatialAmplitudeGateDifferenceRMS
        padAmplitudeGateClosedOutputRMS =
            padRender.amplitudeGateClosedOutputRMS
        padAmplitudeGateClosedSpatialSendRMS =
            padRender.amplitudeGateClosedSpatialSendRMS
        padFilterModulationDifferenceRMS =
            padRender.filterModulationDifferenceRMS
        padSpatialSendDifferenceRMS = padRender.spatialSendDifferenceRMS
        padSpatialSendSampleHash = padRender.spatialSendSampleHash
        padSpatialSendRMS = padRender.spatialSendRMS
        padSampleHash = padRender.outputSampleHash
        padRMS = padRender.outputRMS
        padPeak = padRender.outputPeak
        renderPassesMatch = block.audioSliceRenderPassesMatch
        bindingValid = composition.bar == block.bar &&
            slice.active == (composition.audioSlice != nil) &&
            slice.triggerCount == (composition.audioSlice?.triggers.count ?? 0) &&
            slice.sourceKind == composition.audioSlice?.sourceKind &&
            slice.texture == composition.audioSlice?.texture &&
            (composition.audioSlice?.texture != .granularMemory ||
                slice.textureSeedFingerprint ==
                    AudioSliceRenderer.textureSeedFingerprint(
                        composition.audioSlice?.textureSeed ?? 0
                    )) &&
            arpeggiatorStepCount == (arpeggiator?.steps.count ?? 0) &&
            (arpeggiator == nil ||
                (renderedAnchors.count == scorePitches.count &&
                    arpeggiatorScorePitchFingerprint ==
                        arpeggiatorRenderPitchFingerprint)) &&
            padRender.active == (pad != nil) &&
            padRender.voiceCount == (pad?.voices.count ?? 0) &&
            padRender.requestedFrequencyRatios ==
                (pad?.voices.map(\.frequencyRatio) ?? []) &&
            padRender.rhythmicModulationRelation ==
                (pad?.rhythmicModulation.relation ?? .neutral) &&
            padRender.rhythmicModulationPhaseOffset ==
                (pad?.rhythmicModulation.phaseOffset ?? 0) &&
            (!padRender.active ||
                padRender.rhythmicModulationPatternFingerprint ==
                    PadRhythmicModulationFingerprint.make(
                        pad?.rhythmicModulation ?? .neutral
                    ))
        finite = slice.finite && padRender.finite &&
            sliceMinimumRate.isFinite && sliceMaximumRate.isFinite &&
            sliceOutputRMS.isFinite && padRMS.isFinite && padPeak.isFinite
            && padMinimumFilterScale.isFinite &&
            padMaximumFilterScale.isFinite &&
            padMinimumSpatialSendScale.isFinite &&
            padMaximumSpatialSendScale.isFinite &&
            padMinimumAmplitudeGateGain.isFinite &&
            padMaximumAmplitudeGateGain.isFinite &&
            padAmplitudeGateDifferenceRMS.isFinite &&
            padSpatialAmplitudeGateDifferenceRMS.isFinite &&
            padAmplitudeGateClosedOutputRMS.isFinite &&
            padAmplitudeGateClosedSpatialSendRMS.isFinite &&
            padFilterModulationDifferenceRMS.isFinite &&
            padSpatialSendDifferenceRMS.isFinite &&
            padSpatialSendRMS.isFinite
    }

    package static func neutral(bar: Int) -> Self {
        Self(
            bar: bar,
            localBar: 0,
            phraseLength: 1,
            section: SectionKind.groove.rawValue,
            arrangementGesture: ArrangementGesture.steady.rawValue,
            sliceActive: false,
            sliceTriggerCount: 0,
            sliceReverseTriggerCount: 0,
            sliceMinimumRate: 1,
            sliceMaximumRate: 1,
            sliceSourceKind: "",
            sliceTexture: "",
            sliceTextureSeedFingerprint: "",
            sliceGrainCount: 0,
            sliceGrainLengthFrames: 0,
            sliceGrainHopFrames: 0,
            sliceGrainPositionHash: "",
            sliceSourceHash: "",
            sliceOutputHash: "",
            sliceOutputRMS: 0,
            arpeggiatorActive: false,
            arpeggiatorDirection: "",
            arpeggiatorRateInSteps: 0,
            arpeggiatorOctaveSpan: 0,
            arpeggiatorStepCount: 0,
            arpeggiatorScorePitchFingerprint: "",
            arpeggiatorRenderPitchFingerprint: "",
            padActive: false,
            padFunction: "",
            padHarmonicDisclosureStage: "",
            padVoiceCount: 0,
            padCommonToneCount: 0,
            padTotalMovement: 0,
            padMaximumLeap: 0,
            padRhythmicModulationRelation: "",
            padRhythmicModulationPhaseOffset: 0,
            padRhythmicModulationPatternFingerprint: "",
            padMinimumFilterScale: 1,
            padMaximumFilterScale: 1,
            padMinimumSpatialSendScale: 1,
            padMaximumSpatialSendScale: 1,
            padMinimumAmplitudeGateGain: 1,
            padMaximumAmplitudeGateGain: 1,
            padAmplitudeGateTransitionFrameCount: 0,
            padAmplitudeGateOpenFrameCount: 0,
            padAmplitudeGateClosedFrameCount: 0,
            padPreAmplitudeGateOutputSampleHash: "",
            padPreAmplitudeGateSpatialSendSampleHash: "",
            padAmplitudeGateDifferenceRMS: 0,
            padSpatialAmplitudeGateDifferenceRMS: 0,
            padAmplitudeGateClosedOutputRMS: 0,
            padAmplitudeGateClosedSpatialSendRMS: 0,
            padFilterModulationDifferenceRMS: 0,
            padSpatialSendDifferenceRMS: 0,
            padSpatialSendSampleHash: "",
            padSpatialSendRMS: 0,
            padSampleHash: "",
            padRMS: 0,
            padPeak: 0,
            renderPassesMatch: true,
            bindingValid: true,
            finite: true
        )
    }

    private init(
        bar: Int, localBar: Int, phraseLength: Int,
        section: String, arrangementGesture: String,
        sliceActive: Bool, sliceTriggerCount: Int,
        sliceReverseTriggerCount: Int, sliceMinimumRate: Double,
        sliceMaximumRate: Double, sliceSourceKind: String,
        sliceTexture: String, sliceTextureSeedFingerprint: String,
        sliceGrainCount: Int, sliceGrainLengthFrames: Int,
        sliceGrainHopFrames: Int, sliceGrainPositionHash: String,
        sliceSourceHash: String,
        sliceOutputHash: String, sliceOutputRMS: Double,
        arpeggiatorActive: Bool, arpeggiatorDirection: String,
        arpeggiatorRateInSteps: Int, arpeggiatorOctaveSpan: Int,
        arpeggiatorStepCount: Int,
        arpeggiatorScorePitchFingerprint: String,
        arpeggiatorRenderPitchFingerprint: String,
        padActive: Bool, padFunction: String,
        padHarmonicDisclosureStage: String,
        padVoiceCount: Int, padCommonToneCount: Int, padTotalMovement: Int,
        padMaximumLeap: Int,
        padRhythmicModulationRelation: String,
        padRhythmicModulationPhaseOffset: Int,
        padRhythmicModulationPatternFingerprint: String,
        padMinimumFilterScale: Double, padMaximumFilterScale: Double,
        padMinimumSpatialSendScale: Double, padMaximumSpatialSendScale: Double,
        padMinimumAmplitudeGateGain: Double,
        padMaximumAmplitudeGateGain: Double,
        padAmplitudeGateTransitionFrameCount: Int,
        padAmplitudeGateOpenFrameCount: Int,
        padAmplitudeGateClosedFrameCount: Int,
        padPreAmplitudeGateOutputSampleHash: String,
        padPreAmplitudeGateSpatialSendSampleHash: String,
        padAmplitudeGateDifferenceRMS: Double,
        padSpatialAmplitudeGateDifferenceRMS: Double,
        padAmplitudeGateClosedOutputRMS: Double,
        padAmplitudeGateClosedSpatialSendRMS: Double,
        padFilterModulationDifferenceRMS: Double,
        padSpatialSendDifferenceRMS: Double,
        padSpatialSendSampleHash: String, padSpatialSendRMS: Double,
        padSampleHash: String, padRMS: Double, padPeak: Double,
        renderPassesMatch: Bool, bindingValid: Bool,
        finite: Bool
    ) {
        self.bar = bar
        self.localBar = localBar
        self.phraseLength = phraseLength
        self.section = section
        self.arrangementGesture = arrangementGesture
        self.sliceActive = sliceActive
        self.sliceTriggerCount = sliceTriggerCount
        self.sliceReverseTriggerCount = sliceReverseTriggerCount
        self.sliceMinimumRate = sliceMinimumRate
        self.sliceMaximumRate = sliceMaximumRate
        self.sliceSourceKind = sliceSourceKind
        self.sliceTexture = sliceTexture
        self.sliceTextureSeedFingerprint = sliceTextureSeedFingerprint
        self.sliceGrainCount = sliceGrainCount
        self.sliceGrainLengthFrames = sliceGrainLengthFrames
        self.sliceGrainHopFrames = sliceGrainHopFrames
        self.sliceGrainPositionHash = sliceGrainPositionHash
        self.sliceSourceHash = sliceSourceHash
        self.sliceOutputHash = sliceOutputHash
        self.sliceOutputRMS = sliceOutputRMS
        self.arpeggiatorActive = arpeggiatorActive
        self.arpeggiatorDirection = arpeggiatorDirection
        self.arpeggiatorRateInSteps = arpeggiatorRateInSteps
        self.arpeggiatorOctaveSpan = arpeggiatorOctaveSpan
        self.arpeggiatorStepCount = arpeggiatorStepCount
        self.arpeggiatorScorePitchFingerprint =
            arpeggiatorScorePitchFingerprint
        self.arpeggiatorRenderPitchFingerprint =
            arpeggiatorRenderPitchFingerprint
        self.padActive = padActive
        self.padFunction = padFunction
        self.padHarmonicDisclosureStage = padHarmonicDisclosureStage
        self.padVoiceCount = padVoiceCount
        self.padCommonToneCount = padCommonToneCount
        self.padTotalMovement = padTotalMovement
        self.padMaximumLeap = padMaximumLeap
        self.padRhythmicModulationRelation = padRhythmicModulationRelation
        self.padRhythmicModulationPhaseOffset =
            padRhythmicModulationPhaseOffset
        self.padRhythmicModulationPatternFingerprint =
            padRhythmicModulationPatternFingerprint
        self.padMinimumFilterScale = padMinimumFilterScale
        self.padMaximumFilterScale = padMaximumFilterScale
        self.padMinimumSpatialSendScale = padMinimumSpatialSendScale
        self.padMaximumSpatialSendScale = padMaximumSpatialSendScale
        self.padMinimumAmplitudeGateGain = padMinimumAmplitudeGateGain
        self.padMaximumAmplitudeGateGain = padMaximumAmplitudeGateGain
        self.padAmplitudeGateTransitionFrameCount =
            padAmplitudeGateTransitionFrameCount
        self.padAmplitudeGateOpenFrameCount = padAmplitudeGateOpenFrameCount
        self.padAmplitudeGateClosedFrameCount =
            padAmplitudeGateClosedFrameCount
        self.padPreAmplitudeGateOutputSampleHash =
            padPreAmplitudeGateOutputSampleHash
        self.padPreAmplitudeGateSpatialSendSampleHash =
            padPreAmplitudeGateSpatialSendSampleHash
        self.padAmplitudeGateDifferenceRMS = padAmplitudeGateDifferenceRMS
        self.padSpatialAmplitudeGateDifferenceRMS =
            padSpatialAmplitudeGateDifferenceRMS
        self.padAmplitudeGateClosedOutputRMS =
            padAmplitudeGateClosedOutputRMS
        self.padAmplitudeGateClosedSpatialSendRMS =
            padAmplitudeGateClosedSpatialSendRMS
        self.padFilterModulationDifferenceRMS =
            padFilterModulationDifferenceRMS
        self.padSpatialSendDifferenceRMS = padSpatialSendDifferenceRMS
        self.padSpatialSendSampleHash = padSpatialSendSampleHash
        self.padSpatialSendRMS = padSpatialSendRMS
        self.padSampleHash = padSampleHash
        self.padRMS = padRMS
        self.padPeak = padPeak
        self.renderPassesMatch = renderPassesMatch
        self.bindingValid = bindingValid
        self.finite = finite
    }

    package func isComplete(
        phraseKind: String,
        expectedLocalBar: Int,
        expectedPhraseLength: Int,
        expectedSampleRate: Double
    ) -> Bool {
        guard bar >= 0, renderPassesMatch, bindingValid, finite,
              expectedSampleRate.isFinite,
              expectedSampleRate > 0,
              localBar == expectedLocalBar,
              phraseLength == expectedPhraseLength,
              phraseLength > 0,
              localBar >= 0,
              localBar < phraseLength,
              SectionKind(rawValue: section) != nil,
              ArrangementGesture(rawValue: arrangementGesture) != nil,
              sliceTriggerCount >= 0,
              sliceTriggerCount <= AudioSlicePlan.maximumTriggerCount,
              sliceReverseTriggerCount >= 0,
              sliceReverseTriggerCount <= sliceTriggerCount,
              sliceGrainCount >= 0,
              sliceGrainCount <= AudioSlicePlan.maximumTriggerCount *
                AudioSliceRenderer.maximumGrainsPerTrigger,
              sliceGrainLengthFrames >= 0,
              sliceGrainHopFrames >= 0,
              arpeggiatorStepCount >= 0,
              arpeggiatorStepCount <= ArpeggiatorPlan.maximumStepCount,
              padVoiceCount >= 0,
              padVoiceCount <= PadVoicing.voiceCount,
              padCommonToneCount >= 0,
              padCommonToneCount <= PadVoicing.voiceCount,
              padTotalMovement >= 0, padMaximumLeap >= 0,
              sliceOutputRMS >= 0, padRMS >= 0, padRMS <= padPeak,
              padMinimumFilterScale > 0,
              padMinimumFilterScale <= padMaximumFilterScale,
              padMinimumSpatialSendScale > 0,
              padMinimumSpatialSendScale <= padMaximumSpatialSendScale,
              (0...1).contains(padMinimumAmplitudeGateGain),
              padMinimumAmplitudeGateGain <= padMaximumAmplitudeGateGain,
              (0...1).contains(padMaximumAmplitudeGateGain),
              padAmplitudeGateTransitionFrameCount >= 0,
              padAmplitudeGateOpenFrameCount >= 0,
              padAmplitudeGateClosedFrameCount >= 0,
              padAmplitudeGateDifferenceRMS >= 0,
              padAmplitudeGateDifferenceRMS <= 2,
              padSpatialAmplitudeGateDifferenceRMS >= 0,
              padSpatialAmplitudeGateDifferenceRMS <= 2,
              padAmplitudeGateClosedOutputRMS >= 0,
              padAmplitudeGateClosedOutputRMS <= 2,
              padAmplitudeGateClosedSpatialSendRMS >= 0,
              padAmplitudeGateClosedSpatialSendRMS <= 2,
              padFilterModulationDifferenceRMS >= 0,
              padFilterModulationDifferenceRMS <= 2,
              padSpatialSendDifferenceRMS >= 0,
              padSpatialSendDifferenceRMS <= 2,
              padSpatialSendRMS >= 0, padSpatialSendRMS <= 2 else {
            return false
        }
        if sliceActive {
            guard sliceTriggerCount > 0, sliceOutputRMS > 0,
                  AudioSliceSourceKind(rawValue: sliceSourceKind) != nil,
                  let resolvedTexture = AudioSliceTexture(
                    rawValue: sliceTexture
                  ),
                  isHash(sliceSourceHash), isHash(sliceOutputHash),
                  (0.5...2).contains(sliceMinimumRate),
                  (0.5...2).contains(sliceMaximumRate),
                  sliceMinimumRate <= sliceMaximumRate else { return false }
            switch resolvedTexture {
            case .cut:
                guard sliceTextureSeedFingerprint.isEmpty,
                      sliceGrainCount == 0,
                      sliceGrainLengthFrames == 0,
                      sliceGrainHopFrames == 0,
                      sliceGrainPositionHash.isEmpty else { return false }
            case .granularMemory:
                guard isHash(sliceTextureSeedFingerprint),
                      sliceGrainCount > 0,
                      sliceGrainLengthFrames >= 2,
                      sliceGrainHopFrames > 0,
                      sliceGrainHopFrames <= sliceGrainLengthFrames,
                      isHash(sliceGrainPositionHash) else { return false }
            }
        } else if sliceTriggerCount != 0 || sliceReverseTriggerCount != 0 ||
                    sliceMinimumRate != 1 || sliceMaximumRate != 1 ||
                    !sliceSourceKind.isEmpty || !sliceTexture.isEmpty ||
                    !sliceTextureSeedFingerprint.isEmpty ||
                    sliceGrainCount != 0 || sliceGrainLengthFrames != 0 ||
                    sliceGrainHopFrames != 0 ||
                    !sliceGrainPositionHash.isEmpty ||
                    !sliceSourceHash.isEmpty || !sliceOutputHash.isEmpty ||
                    sliceOutputRMS.bitPattern != 0 {
            return false
        }
        if arpeggiatorActive {
            guard ArpeggiatorDirection(rawValue: arpeggiatorDirection) != nil,
                  (1...4).contains(arpeggiatorRateInSteps),
                  (1...2).contains(arpeggiatorOctaveSpan),
                  arpeggiatorStepCount >= 4,
                  isHash(arpeggiatorScorePitchFingerprint),
                  arpeggiatorScorePitchFingerprint ==
                    arpeggiatorRenderPitchFingerprint else { return false }
        } else if !arpeggiatorDirection.isEmpty || arpeggiatorRateInSteps != 0 ||
                    arpeggiatorOctaveSpan != 0 || arpeggiatorStepCount != 0 ||
                    !arpeggiatorScorePitchFingerprint.isEmpty ||
                    !arpeggiatorRenderPitchFingerprint.isEmpty {
            return false
        }
        if padActive {
            guard let resolvedPhraseKind = AutonomousPhraseKind(
                    rawValue: phraseKind
                  ),
                  let resolvedFunction = PadHarmonicFunction(
                    rawValue: padFunction
                  ),
                  let disclosureStage = PadHarmonicDisclosureStage(
                    rawValue: padHarmonicDisclosureStage
                  ),
                  let modulationRelation = PadRhythmicModulationRelation(
                    rawValue: padRhythmicModulationRelation
                  ),
                  padVoiceCount == PadVoicing.voiceCount,
                  padRMS > 0, padPeak > 0, isHash(padSampleHash),
                  padSpatialSendRMS > 0,
                  isHash(padSpatialSendSampleHash),
                  padMaximumLeap <= 12 else { return false }
            let expectedDisclosureStage = PhraseCompositionResolver
                .harmonicDisclosureStage(
                    kind: resolvedPhraseKind,
                    localBar: localBar,
                    phraseLength: phraseLength
                )
            guard disclosureStage == expectedDisclosureStage else {
                return false
            }
            if disclosureStage != .established {
                let expectedFunction = PhraseCompositionResolver
                    .disclosedHarmonicFunction(
                        established: .tonic,
                        kind: resolvedPhraseKind,
                        localBar: localBar,
                        phraseLength: phraseLength
                    )
                guard resolvedFunction == expectedFunction else { return false }
            }
            let modulation = PadRhythmicModulation(
                relation: modulationRelation,
                phaseOffset: padRhythmicModulationPhaseOffset
            )
            guard padRhythmicModulationPatternFingerprint ==
                    PadRhythmicModulationFingerprint.make(modulation) else {
                return false
            }
            switch modulationRelation {
            case .neutral:
                guard padRhythmicModulationPhaseOffset == 0,
                      padMinimumFilterScale == 1,
                      padMaximumFilterScale == 1,
                      padMinimumSpatialSendScale == 1,
                      padMaximumSpatialSendScale == 1,
                      padMinimumAmplitudeGateGain == 1,
                      padMaximumAmplitudeGateGain == 1,
                      padAmplitudeGateTransitionFrameCount == 0,
                      padAmplitudeGateOpenFrameCount == 0,
                      padAmplitudeGateClosedFrameCount == 0,
                      padPreAmplitudeGateOutputSampleHash == padSampleHash,
                      padPreAmplitudeGateSpatialSendSampleHash ==
                        padSpatialSendSampleHash,
                      padAmplitudeGateDifferenceRMS.bitPattern == 0,
                      padSpatialAmplitudeGateDifferenceRMS.bitPattern == 0,
                      padAmplitudeGateClosedOutputRMS.bitPattern == 0,
                      padAmplitudeGateClosedSpatialSendRMS.bitPattern == 0,
                      padFilterModulationDifferenceRMS.bitPattern == 0,
                      padSpatialSendDifferenceRMS.bitPattern == 0 else {
                    return false
                }
            case .threeStepPulse:
                guard phraseKind == AutonomousPhraseKind.majorBreak.rawValue,
                      section == SectionKind.breakdown.rawValue,
                      (8...14).contains(bar % 16),
                      arrangementGesture != ArrangementGesture.minimalize.rawValue,
                      arrangementGesture != ArrangementGesture.structuralMarker.rawValue,
                      (0..<PadRhythmicModulation.cellLength).contains(
                    padRhythmicModulationPhaseOffset
                ),
                      padRhythmicModulationPhaseOffset ==
                        bar % PadRhythmicModulation.cellLength,
                      padMinimumFilterScale == 0.38,
                      padMaximumFilterScale == 1,
                      padMinimumSpatialSendScale == 0.72,
                      padMaximumSpatialSendScale == 1.28,
                      padMinimumAmplitudeGateGain == 0,
                      padMaximumAmplitudeGateGain == 1,
                      padAmplitudeGateTransitionFrameCount == max(
                        2,
                        Int((expectedSampleRate *
                            PolyphonicPadVoice.amplitudeGateTransitionSeconds)
                            .rounded())
                      ),
                      padAmplitudeGateOpenFrameCount > 0,
                      padAmplitudeGateClosedFrameCount >
                        padAmplitudeGateOpenFrameCount,
                      padAmplitudeGateOpenFrameCount +
                        padAmplitudeGateClosedFrameCount == max(
                            1,
                            Int((
                                240.0 / AutonomousSessionDirector.bpm *
                                    expectedSampleRate
                            ).rounded())
                        ),
                      isHash(padPreAmplitudeGateOutputSampleHash),
                      isHash(padPreAmplitudeGateSpatialSendSampleHash),
                      padPreAmplitudeGateOutputSampleHash != padSampleHash,
                      padPreAmplitudeGateSpatialSendSampleHash !=
                        padSpatialSendSampleHash,
                      padAmplitudeGateDifferenceRMS > 0,
                      padSpatialAmplitudeGateDifferenceRMS > 0,
                      padAmplitudeGateClosedOutputRMS.bitPattern == 0,
                      padAmplitudeGateClosedSpatialSendRMS.bitPattern == 0,
                      padFilterModulationDifferenceRMS > 0,
                      padSpatialSendDifferenceRMS > 0 else {
                    return false
                }
            }
            let shouldApplyRhythmicModulation =
                phraseKind == AutonomousPhraseKind.majorBreak.rawValue &&
                section == SectionKind.breakdown.rawValue &&
                (8...14).contains(bar % 16) &&
                arrangementGesture != ArrangementGesture.minimalize.rawValue &&
                arrangementGesture != ArrangementGesture.structuralMarker.rawValue
            guard (modulationRelation == .threeStepPulse) ==
                    shouldApplyRhythmicModulation else {
                return false
            }
        } else if !padFunction.isEmpty ||
                    !padHarmonicDisclosureStage.isEmpty ||
                    padVoiceCount != 0 ||
                    padCommonToneCount != 0 || padTotalMovement != 0 ||
                    padMaximumLeap != 0 || !padSampleHash.isEmpty ||
                    !padRhythmicModulationRelation.isEmpty ||
                    padRhythmicModulationPhaseOffset != 0 ||
                    !padRhythmicModulationPatternFingerprint.isEmpty ||
                    padMinimumFilterScale != 1 ||
                    padMaximumFilterScale != 1 ||
                    padMinimumSpatialSendScale != 1 ||
                    padMaximumSpatialSendScale != 1 ||
                    padMinimumAmplitudeGateGain != 1 ||
                    padMaximumAmplitudeGateGain != 1 ||
                    padAmplitudeGateTransitionFrameCount != 0 ||
                    padAmplitudeGateOpenFrameCount != 0 ||
                    padAmplitudeGateClosedFrameCount != 0 ||
                    !padPreAmplitudeGateOutputSampleHash.isEmpty ||
                    !padPreAmplitudeGateSpatialSendSampleHash.isEmpty ||
                    padAmplitudeGateDifferenceRMS.bitPattern != 0 ||
                    padSpatialAmplitudeGateDifferenceRMS.bitPattern != 0 ||
                    padAmplitudeGateClosedOutputRMS.bitPattern != 0 ||
                    padAmplitudeGateClosedSpatialSendRMS.bitPattern != 0 ||
                    padFilterModulationDifferenceRMS.bitPattern != 0 ||
                    padSpatialSendDifferenceRMS.bitPattern != 0 ||
                    !padSpatialSendSampleHash.isEmpty ||
                    padSpatialSendRMS.bitPattern != 0 ||
                    padRMS.bitPattern != 0 || padPeak.bitPattern != 0 {
            return false
        }
        return true
    }

    private func isHash(_ value: String) -> Bool {
        value.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
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
    package let relation: String
    package let performanceCharacter: String
    package let bpm: Double
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let sourceScoreNoteCount: Int
    package let sourceRenderEventCount: Int
    package let anchorEventCount: Int
    package let activeOffsetCount: Int
    package let protectedRoleActiveOffsetCount: Int
    package let anchorActiveOffsetCount: Int
    package let minimumOffsetInSteps: Double
    package let maximumOffsetInSteps: Double
    package let maximumRoleSpreadInSteps: Double
    package let anchorMinimumOffsetInSteps: Double
    package let anchorMaximumOffsetInSteps: Double
    package let anchorOffsetPatternFingerprint: String
    package let shadowMinimumOffsetInSteps: Double
    package let shadowMaximumOffsetInSteps: Double
    package let responseMinimumOffsetInSteps: Double
    package let responseMaximumOffsetInSteps: Double
    package let scoreFingerprint: String
    package let renderFingerprint: String
    package let appliedGateFingerprint: String
    package let anchorSignal: AutonomousUpperTimingRoleSignalEvidence
    package let shadowSignal: AutonomousUpperTimingRoleSignalEvidence
    package let responseSignal: AutonomousUpperTimingRoleSignalEvidence
    package let bindingValid: Bool
    package let finite: Bool

    package init(
        bar: Int,
        chapter: InterlockChapter,
        relation: UpperTimingRelation = .aligned,
        performanceCharacter: PerformanceCharacter = .hypnoticLock,
        bpm: Double,
        sampleRate: Double,
        renderedFrameCount: Int,
        sourceScoreNoteCount: Int,
        sourceRenderEventCount: Int,
        anchorEventCount: Int,
        activeOffsetCount: Int,
        protectedRoleActiveOffsetCount: Int,
        anchorActiveOffsetCount: Int = 0,
        minimumOffsetInSteps: Double,
        maximumOffsetInSteps: Double,
        maximumRoleSpreadInSteps: Double,
        anchorMinimumOffsetInSteps: Double = 0,
        anchorMaximumOffsetInSteps: Double = 0,
        anchorOffsetPatternFingerprint: String,
        shadowMinimumOffsetInSteps: Double,
        shadowMaximumOffsetInSteps: Double,
        responseMinimumOffsetInSteps: Double,
        responseMaximumOffsetInSteps: Double,
        scoreFingerprint: String,
        renderFingerprint: String,
        appliedGateFingerprint: String,
        anchorSignal: AutonomousUpperTimingRoleSignalEvidence,
        shadowSignal: AutonomousUpperTimingRoleSignalEvidence,
        responseSignal: AutonomousUpperTimingRoleSignalEvidence,
        bindingValid: Bool,
        finite: Bool
    ) {
        self.bar = bar
        self.chapter = chapter.rawValue
        self.relation = relation.rawValue
        self.performanceCharacter = performanceCharacter.rawValue
        self.bpm = bpm
        self.sampleRate = sampleRate
        self.renderedFrameCount = renderedFrameCount
        self.sourceScoreNoteCount = sourceScoreNoteCount
        self.sourceRenderEventCount = sourceRenderEventCount
        self.anchorEventCount = anchorEventCount
        self.activeOffsetCount = activeOffsetCount
        self.protectedRoleActiveOffsetCount = protectedRoleActiveOffsetCount
        self.anchorActiveOffsetCount = anchorActiveOffsetCount
        self.minimumOffsetInSteps = minimumOffsetInSteps
        self.maximumOffsetInSteps = maximumOffsetInSteps
        self.maximumRoleSpreadInSteps = maximumRoleSpreadInSteps
        self.anchorMinimumOffsetInSteps = anchorMinimumOffsetInSteps
        self.anchorMaximumOffsetInSteps = anchorMaximumOffsetInSteps
        self.anchorOffsetPatternFingerprint = anchorOffsetPatternFingerprint
        self.shadowMinimumOffsetInSteps = shadowMinimumOffsetInSteps
        self.shadowMaximumOffsetInSteps = shadowMaximumOffsetInSteps
        self.responseMinimumOffsetInSteps = responseMinimumOffsetInSteps
        self.responseMaximumOffsetInSteps = responseMaximumOffsetInSteps
        self.scoreFingerprint = scoreFingerprint
        self.renderFingerprint = renderFingerprint
        self.appliedGateFingerprint = appliedGateFingerprint
        self.anchorSignal = anchorSignal
        self.shadowSignal = shadowSignal
        self.responseSignal = responseSignal
        self.bindingValid = bindingValid
        self.finite = finite
    }

    package var isFinite: Bool {
        finite && [
            bpm, sampleRate, minimumOffsetInSteps, maximumOffsetInSteps,
            maximumRoleSpreadInSteps, shadowMinimumOffsetInSteps,
            anchorMinimumOffsetInSteps, anchorMaximumOffsetInSteps,
            shadowMaximumOffsetInSteps, responseMinimumOffsetInSteps,
            responseMaximumOffsetInSteps,
        ].allSatisfy(\.isFinite) && anchorSignal.isFinite &&
            shadowSignal.isFinite && responseSignal.isFinite
    }

    package func normalTimingEligibility(
        phraseKind: AutonomousPhraseKind
    ) -> Bool {
        let cascadeEligible = chapter == InterlockChapter.breath.rawValue &&
            SynthPerformancePlan.upperTimingAperture(absoluteBar: bar) > 0 &&
            anchorEventCount > 0 &&
            (shadowSignal.eventCount > 0 || responseSignal.eventCount > 0) &&
            phraseKind != .identityReturn && phraseKind != .majorBreak
        let leadPerformanceEligible =
            chapter == InterlockChapter.home.rawValue &&
            performanceCharacter == PerformanceCharacter.melodicGlow.rawValue &&
            phraseKind == .lock && anchorEventCount >= 2
        return cascadeEligible || leadPerformanceEligible
    }

    package func isComplete(
        routeSampleRate: Double,
        phraseKind: AutonomousPhraseKind
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
              let timingRelation = UpperTimingRelation(rawValue: relation),
              PerformanceCharacter(rawValue: performanceCharacter) != nil,
              bpm == AutonomousSessionDirector.bpm,
              sampleRate == routeSampleRate,
              sampleRate >= QualityQualificationContract.minimumSupportedSampleRate,
              sampleRate <= QualityQualificationContract.maximumSupportedSampleRate,
              renderedFrameCount == Self.barFrames(bpm: bpm, sampleRate: sampleRate),
              sourceScoreNoteCount >= 0, sourceScoreNoteCount <= maximumEvents,
              sourceRenderEventCount == sourceScoreNoteCount,
              anchorEventCount >= 0, anchorEventCount <= sourceRenderEventCount,
              activeOffsetCount >= 0, activeOffsetCount <= sourceScoreNoteCount,
              protectedRoleActiveOffsetCount >= 0,
              protectedRoleActiveOffsetCount == 0,
              anchorActiveOffsetCount >= 0,
              anchorActiveOffsetCount <= anchorEventCount,
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
                anchorMinimumOffsetInSteps
              ),
              (0...ResolvedUpperNote.maximumTimingOffsetInSteps).contains(
                anchorMaximumOffsetInSteps
              ),
              anchorMinimumOffsetInSteps <= anchorMaximumOffsetInSteps,
              Self.isFingerprint(anchorOffsetPatternFingerprint),
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
              anchorSignal.isComplete(
                expectedRole: .anchor,
                maximumEventCount: sourceScoreNoteCount
              ),
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
        let anchorSignalIsAudible = anchorSignal.eventCount == 0 ||
            (anchorSignal.peak > 0 && anchorSignal.rms > 0)
        guard companionRoleSignalsAreAudible, anchorSignalIsAudible,
              anchorSignal.eventCount == anchorEventCount else { return false }

        let expectedAnchorOffsets: [Double]
        if timingRelation == .leadPerformance {
            expectedAnchorOffsets = (0..<anchorEventCount).map {
                SynthPerformancePlan.leadPerformanceOffsetInSteps(
                    performanceIndex: $0
                )
            }
        } else {
            expectedAnchorOffsets = Array(repeating: 0, count: anchorEventCount)
        }
        guard anchorOffsetPatternFingerprint ==
                Self.offsetPatternFingerprint(expectedAnchorOffsets),
              anchorMinimumOffsetInSteps == (expectedAnchorOffsets.min() ?? 0),
              anchorMaximumOffsetInSteps == (expectedAnchorOffsets.max() ?? 0) else {
            return false
        }

        if timingRelation == .leadPerformance {
            let expectedActive = max(0, anchorEventCount - 1)
            return chapter == InterlockChapter.home.rawValue &&
                performanceCharacter == PerformanceCharacter.melodicGlow.rawValue &&
                phraseKind == .lock &&
                anchorEventCount >= 2 &&
                activeOffsetCount == expectedActive &&
                anchorActiveOffsetCount == expectedActive &&
                protectedRoleActiveOffsetCount == 0 &&
                minimumOffsetInSteps.bitPattern == 0 &&
                anchorMinimumOffsetInSteps.bitPattern == 0 &&
                anchorMaximumOffsetInSteps >=
                    SynthPerformancePlan.minimumLeadPerformanceOffsetInSteps &&
                anchorMaximumOffsetInSteps <=
                    SynthPerformancePlan.maximumLeadPerformanceOffsetInSteps &&
                maximumOffsetInSteps == anchorMaximumOffsetInSteps &&
                maximumRoleSpreadInSteps == anchorMaximumOffsetInSteps &&
                shadowMinimumOffsetInSteps.bitPattern == 0 &&
                shadowMaximumOffsetInSteps.bitPattern == 0 &&
                responseMinimumOffsetInSteps.bitPattern == 0 &&
                responseMaximumOffsetInSteps.bitPattern == 0
        }

        let isMacroEndpoint = bar.isMultiple(of: 16) ||
            ((bar % 16) + 16) % 16 == 15
        if activeOffsetCount == 0 || isMacroEndpoint {
            return timingRelation == .aligned && activeOffsetCount == 0 &&
                anchorActiveOffsetCount == 0 &&
                minimumOffsetInSteps.bitPattern == 0 &&
                maximumOffsetInSteps.bitPattern == 0 &&
                maximumRoleSpreadInSteps.bitPattern == 0 &&
                anchorMinimumOffsetInSteps.bitPattern == 0 &&
                anchorMaximumOffsetInSteps.bitPattern == 0 &&
                shadowMinimumOffsetInSteps.bitPattern == 0 &&
                shadowMaximumOffsetInSteps.bitPattern == 0 &&
                responseMinimumOffsetInSteps.bitPattern == 0 &&
                responseMaximumOffsetInSteps.bitPattern == 0
        }

        guard timingRelation == .harmonicCascade,
              chapter == InterlockChapter.breath.rawValue,
              phraseKind != .identityReturn,
              phraseKind != .majorBreak,
              anchorEventCount > 0,
              anchorActiveOffsetCount == 0,
              anchorMinimumOffsetInSteps.bitPattern == 0,
              anchorMaximumOffsetInSteps.bitPattern == 0,
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

    package static func offsetPatternFingerprint(_ offsets: [Double]) -> String {
        var sink = StreamingFNV1a()
        sink.domain("upper-timing-anchor-offsets.typed.v1")
        sink.collection(offsets.count)
        for offset in offsets {
            sink.double(offset)
        }
        return fixedWidthFingerprintHex(sink.value)
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
            hasPulseEchoAccess && hasTimelyPulseEchoOnset &&
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
        instruments: AutonomousInstrumentBarEvidence
    ) -> Bool {
        interlockChapter == InterlockChapter.memory.rawValue && scoreEnabled &&
            hasPulseEchoAccess(in: instruments) &&
            earliestPulseEchoOnsetStep.map {
                $0 <= PulseEchoTextureArticulation.latestDrivenOnsetStep
            } == true &&
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

/// Bounded candidate projection of the canonical late spatial field. It keeps
/// only score/configuration identity and reduced PCM facts; FDN delay memory
/// remains renderer continuation and never enters the quality vector.
package struct AutonomousSpatialFDNBarEvidence: Codable, Equatable, Sendable {
    package let bar: Int
    package let sampleRate: Double
    package let renderedFrameCount: Int
    package let lineCount: Int
    package let delayFrameCounts: [Int]
    package let requestedRoomScale: Double
    package let roomScale: Double
    package let decayTimeSeconds: Double
    package let dampingHz: Double
    package let maximumFeedbackGain: Double
    package let synthSendGain: Double
    package let percussionSendGain: Double
    package let wetGain: Double
    package let geometryRetained: Bool
    package let parameterTransitionFrameCount: Int
    package let initialMaximumFeedbackGain: Double
    package let finalMaximumFeedbackGain: Double
    package let initialDampingCoefficient: Double
    package let finalDampingCoefficient: Double
    package let initialSynthSendGain: Double
    package let finalSynthSendGain: Double
    package let initialPercussionSendGain: Double
    package let finalPercussionSendGain: Double
    package let initialWetGain: Double
    package let finalWetGain: Double
    package let spatialDepthPosition: String
    package let carrierVoice: String?
    package let carrierStep: Int?
    package let scoreReverbSend: Double
    package let scoreHighPassHz: Double
    package let scoreLowPassHz: Double
    package let inputSampleHash: String
    package let wetLeftSampleHash: String
    package let wetRightSampleHash: String
    package let inputRMS: Double
    package let spatialSendRMS: Double
    package let wetPeak: Double
    package let wetRMS: Double
    package let wetStereoCorrelation: Double
    package let activeInputFrameCount: Int
    package let activeWetFrameCount: Int
    package let firstWetFrameIndex: Int
    package let openingWindowFrameCount: Int
    package let openingWetRMS: Double
    package let terminalWindowFrameCount: Int
    package let terminalWetRMS: Double
    package let bindingValid: Bool
    package let finite: Bool

    package init(
        _ evidence: SpatialFDNRenderEvidence,
        bindingValid: Bool
    ) {
        bar = evidence.bar
        sampleRate = evidence.sampleRate
        renderedFrameCount = evidence.renderedFrameCount
        lineCount = evidence.lineCount
        delayFrameCounts = evidence.delayFrameCounts
        requestedRoomScale = evidence.requestedRoomScale
        roomScale = evidence.roomScale
        decayTimeSeconds = evidence.decayTimeSeconds
        dampingHz = evidence.dampingHz
        maximumFeedbackGain = evidence.maximumFeedbackGain
        synthSendGain = evidence.synthSendGain
        percussionSendGain = evidence.percussionSendGain
        wetGain = evidence.wetGain
        geometryRetained = evidence.geometryRetained
        parameterTransitionFrameCount =
            evidence.parameterTransitionFrameCount
        initialMaximumFeedbackGain =
            evidence.initialMaximumFeedbackGain
        finalMaximumFeedbackGain = evidence.finalMaximumFeedbackGain
        initialDampingCoefficient = evidence.initialDampingCoefficient
        finalDampingCoefficient = evidence.finalDampingCoefficient
        initialSynthSendGain = evidence.initialSynthSendGain
        finalSynthSendGain = evidence.finalSynthSendGain
        initialPercussionSendGain = evidence.initialPercussionSendGain
        finalPercussionSendGain = evidence.finalPercussionSendGain
        initialWetGain = evidence.initialWetGain
        finalWetGain = evidence.finalWetGain
        spatialDepthPosition = evidence.spatialDepthPosition.rawValue
        carrierVoice = evidence.carrierVoice?.rawValue
        carrierStep = evidence.carrierStep
        scoreReverbSend = evidence.scoreReverbSend
        scoreHighPassHz = evidence.scoreHighPassHz
        scoreLowPassHz = evidence.scoreLowPassHz
        inputSampleHash = evidence.inputSampleHash
        wetLeftSampleHash = evidence.wetLeftSampleHash
        wetRightSampleHash = evidence.wetRightSampleHash
        inputRMS = evidence.inputRMS
        spatialSendRMS = evidence.spatialSendRMS
        wetPeak = evidence.wetPeak
        wetRMS = evidence.wetRMS
        wetStereoCorrelation = evidence.wetStereoCorrelation
        activeInputFrameCount = evidence.activeInputFrameCount
        activeWetFrameCount = evidence.activeWetFrameCount
        firstWetFrameIndex = evidence.firstWetFrameIndex
        openingWindowFrameCount = evidence.openingWindowFrameCount
        openingWetRMS = evidence.openingWetRMS
        terminalWindowFrameCount = evidence.terminalWindowFrameCount
        terminalWetRMS = evidence.terminalWetRMS
        self.bindingValid = bindingValid
        finite = evidence.finite
    }

    package static func neutral(
        bar: Int,
        sampleRate: Double
    ) -> AutonomousSpatialFDNBarEvidence {
        let configuration = FeedbackDelayNetworkConfiguration(
            sampleRate: sampleRate,
            roomScale: 1,
            decayTimeSeconds:
                FeedbackDelayNetworkConfiguration.minimumDecayTimeSeconds,
            dampingHz: FeedbackDelayNetworkConfiguration.minimumDampingHz,
            synthSendGain: 0,
            percussionSendGain: 0,
            wetGain: 0
        )
        let frameCount = max(1, Int((
            240.0 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded()))
        return AutonomousSpatialFDNBarEvidence(
            SpatialFDNRenderEvidence(
                bar: bar,
                sampleRate: sampleRate,
                renderedFrameCount: frameCount,
                lineCount: FeedbackDelayNetworkConfiguration.lineCount,
                delayFrameCounts: configuration.delayFrameCounts,
                requestedRoomScale: configuration.roomScale,
                roomScale: configuration.roomScale,
                decayTimeSeconds: configuration.decayTimeSeconds,
                dampingHz: configuration.dampingHz,
                maximumFeedbackGain: configuration.maximumFeedbackGain,
                synthSendGain: configuration.synthSendGain,
                percussionSendGain: configuration.percussionSendGain,
                wetGain: configuration.wetGain,
                geometryRetained: false,
                parameterTransitionFrameCount: 0,
                initialMaximumFeedbackGain:
                    configuration.maximumFeedbackGain,
                finalMaximumFeedbackGain:
                    configuration.maximumFeedbackGain,
                initialDampingCoefficient:
                    configuration.dampingCoefficient,
                finalDampingCoefficient:
                    configuration.dampingCoefficient,
                initialSynthSendGain: configuration.synthSendGain,
                finalSynthSendGain: configuration.synthSendGain,
                initialPercussionSendGain:
                    configuration.percussionSendGain,
                finalPercussionSendGain:
                    configuration.percussionSendGain,
                initialWetGain: configuration.wetGain,
                finalWetGain: configuration.wetGain,
                spatialDepthPosition: .foreground,
                carrierVoice: nil,
                carrierStep: nil,
                scoreReverbSend: 0,
                scoreHighPassHz: 300,
                scoreLowPassHz: 4_200,
                inputSampleHash: "0123456789abcdef",
                wetLeftSampleHash: "0123456789abcdef",
                wetRightSampleHash: "0123456789abcdef",
                inputRMS: 0,
                spatialSendRMS: 0,
                wetPeak: 0,
                wetRMS: 0,
                wetStereoCorrelation: 0,
                activeInputFrameCount: 0,
                activeWetFrameCount: 0,
                firstWetFrameIndex: -1,
                openingWindowFrameCount: min(
                    frameCount,
                    max(1, Int((sampleRate * 0.25).rounded()))
                ),
                openingWetRMS: 0,
                terminalWindowFrameCount: min(
                    frameCount,
                    max(1, Int((sampleRate * 0.25).rounded()))
                ),
                terminalWetRMS: 0,
                finite: true
            ),
            bindingValid: true
        )
    }

    package var isFinite: Bool {
        finite && [
            sampleRate, requestedRoomScale, roomScale, decayTimeSeconds, dampingHz,
            maximumFeedbackGain, synthSendGain, percussionSendGain, wetGain,
            initialMaximumFeedbackGain, finalMaximumFeedbackGain,
            initialDampingCoefficient, finalDampingCoefficient,
            initialSynthSendGain, finalSynthSendGain,
            initialPercussionSendGain, finalPercussionSendGain,
            initialWetGain, finalWetGain,
            scoreReverbSend, scoreHighPassHz, scoreLowPassHz, inputRMS,
            spatialSendRMS, wetPeak, wetRMS, wetStereoCorrelation,
            openingWetRMS, terminalWetRMS,
        ].allSatisfy { $0.isFinite }
    }

    package func isComplete(routeSampleRate: Double) -> Bool {
        let expectedFrames = max(1, Int((
            240.0 / AutonomousSessionDirector.bpm * routeSampleRate
        ).rounded()))
        let retainedConfiguration = FeedbackDelayNetworkConfiguration(
            sampleRate: routeSampleRate,
            roomScale: roomScale,
            decayTimeSeconds: decayTimeSeconds,
            dampingHz: dampingHz,
            synthSendGain: synthSendGain,
            percussionSendGain: percussionSendGain,
            wetGain: wetGain
        )
        guard isFinite, bindingValid, bar >= 0,
              sampleRate == routeSampleRate,
              renderedFrameCount == expectedFrames,
              retainedConfiguration.isBoundedAndStable,
              lineCount == FeedbackDelayNetworkConfiguration.lineCount,
              delayFrameCounts == retainedConfiguration.delayFrameCounts,
              maximumFeedbackGain ==
                retainedConfiguration.maximumFeedbackGain,
              requestedRoomScale >=
                FeedbackDelayNetworkConfiguration.minimumRoomScale,
              requestedRoomScale <=
                FeedbackDelayNetworkConfiguration.maximumRoomScale,
              zip(
                delayFrameCounts,
                delayFrameCounts.dropFirst()
              ).allSatisfy({ $0 < $1 }),
              delayFrameCounts.allSatisfy({ frames in
                  frames >= 3 && !frames.isMultiple(of: 2) &&
                      frames <= Int(
                          routeSampleRate *
                            FeedbackDelayNetworkConfiguration.maximumDelaySeconds
                      ) + 1
              }),
              roomScale >= FeedbackDelayNetworkConfiguration.minimumRoomScale,
              roomScale <= FeedbackDelayNetworkConfiguration.maximumRoomScale,
              decayTimeSeconds >=
                FeedbackDelayNetworkConfiguration.minimumDecayTimeSeconds,
              decayTimeSeconds <=
                FeedbackDelayNetworkConfiguration.maximumDecayTimeSeconds,
              dampingHz >= FeedbackDelayNetworkConfiguration.minimumDampingHz,
              dampingHz <= routeSampleRate * 0.45,
              maximumFeedbackGain > 0, maximumFeedbackGain < 1,
              initialMaximumFeedbackGain > 0,
              initialMaximumFeedbackGain < 1,
              finalMaximumFeedbackGain == maximumFeedbackGain,
              (0...1).contains(initialDampingCoefficient),
              finalDampingCoefficient ==
                retainedConfiguration.dampingCoefficient,
              (0...0.5).contains(synthSendGain),
              (0...0.5).contains(initialSynthSendGain),
              finalSynthSendGain == synthSendGain,
              (0...0.16).contains(percussionSendGain),
              (0...0.16).contains(initialPercussionSendGain),
              finalPercussionSendGain == percussionSendGain,
              (0...0.24).contains(wetGain),
              (0...0.24).contains(initialWetGain),
              finalWetGain == wetGain,
              parameterTransitionFrameCount >= 0,
              parameterTransitionFrameCount <= max(1, Int((
                routeSampleRate *
                    FeedbackDelayNetworkState.parameterTransitionSeconds
              ).rounded())),
              let depth = SpatialDepthPosition(rawValue: spatialDepthPosition),
              carrierVoice.flatMap(EnsembleVoice.init(rawValue:)) != nil ||
                carrierVoice == nil,
              carrierStep.map({ (0..<16).contains($0) }) ?? true,
              (0...1).contains(scoreReverbSend),
              scoreHighPassHz >= 20,
              scoreLowPassHz >= scoreHighPassHz,
              scoreLowPassHz <= 20_000,
              Self.isSampleHash(inputSampleHash),
              Self.isSampleHash(wetLeftSampleHash),
              Self.isSampleHash(wetRightSampleHash),
              inputRMS >= 0, spatialSendRMS >= 0,
              wetPeak >= 0, wetRMS >= 0, wetRMS <= wetPeak,
              (-1...1).contains(wetStereoCorrelation),
              (0...renderedFrameCount).contains(activeInputFrameCount),
              (0...renderedFrameCount).contains(activeWetFrameCount),
              openingWindowFrameCount == min(
                renderedFrameCount,
                max(1, Int((routeSampleRate * 0.25).rounded()))
              ),
              terminalWindowFrameCount == openingWindowFrameCount,
              openingWetRMS >= 0, openingWetRMS <= wetPeak,
              terminalWetRMS >= 0, terminalWetRMS <= wetPeak else {
            return false
        }
        let depthIsCoherent: Bool
        switch depth {
        case .foreground:
            depthIsCoherent = carrierVoice == nil && carrierStep == nil &&
                scoreReverbSend == 0
        case .distant:
            depthIsCoherent = carrierVoice != nil && carrierStep != nil &&
                scoreReverbSend > 0
        }
        let inputIsCoherent = (activeInputFrameCount == 0) == (inputRMS == 0)
        let wetIsCoherent = activeWetFrameCount == 0
            ? wetPeak == 0 && wetRMS == 0 && firstWetFrameIndex == -1
            : wetPeak > 0 && wetRMS > 0 &&
                (0..<renderedFrameCount).contains(firstWetFrameIndex)
        return depthIsCoherent && inputIsCoherent && wetIsCoherent
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

package enum AutonomousCandidateCompletenessFailure: String, Codable,
        Equatable, Sendable {
    case identityAndPrimaryEvidence = "identity-and-primary-evidence"
    case symbolicBarCoverage = "symbolic-bar-coverage"
    case automaticMixControllerTrajectory =
        "automatic-mix-controller-trajectory"
    case sourceCounts = "source-counts"
    case maskingEvidence = "masking-evidence"
    case stemEvidence = "stem-evidence"
    case automaticMixEvidence = "automatic-mix-evidence"
    case kickSyntaxEvidence = "kick-syntax-evidence"
    case foundationRhythmEvidence = "foundation-rhythm-evidence"
    case climaxArcEvidence = "climax-arc-evidence"
    case groovePulseEvidence = "groove-pulse-evidence"
    case closedHatEvidence = "closed-hat-evidence"
    case upperPercussionTailEvidence = "upper-percussion-tail-evidence"
    case modalPercussionEvidence = "modal-percussion-evidence"
    case instrumentEvidence = "instrument-evidence"
    case percussionEchoTextureEvidence = "percussion-echo-texture-evidence"
    case phraseCompositionEvidence = "phrase-composition-evidence"
    case pulseEchoDriveEvidence = "pulse-echo-drive-evidence"
    case spatialFDNEvidence = "spatial-fdn-evidence"
    case crossPhraseTransitionEvidence =
        "cross-phrase-transition-evidence"
    case upperTimingEvidence = "upper-timing-evidence"
    case liveMasterEvidence = "live-master-evidence"
}

package struct AutonomousLiveMasterRenderValidationInput: Sendable {
    package let left: [Float]
    package let right: [Float]
    package let evidence: LiveMasterTrimRenderEvidence

    package init(
        left: [Float],
        right: [Float],
        evidence: LiveMasterTrimRenderEvidence
    ) {
        self.left = left
        self.right = right
        self.evidence = evidence
    }
}

package struct AutonomousValidatedLiveMasterEvidence: Equatable, Sendable {
    package let requestedTrimDB: Double
    package let appliedTrimDB: Double
    package let appliedGain: Double
    package let preTrimPCMFingerprint: String
    package let postTrimPCMFingerprint: String
    package let validatedBlockCount: Int
}

/// The complete reduced evidence vector for one immutable candidate render.
/// Raw PCM and renderer state never enter this value.
package struct AutonomousCandidateEvaluationVector: Codable, Equatable, Sendable {
    package static let schemaVersion = 35
    package static let maximumBarCount = 16
    package static let maximumMaskingObservationsPerBar = 12
    package static let maximumStemRolesPerBar = 5
    package static let maximumGroovePulseEventsPerBar = 8
    package static let maximumClosedHatEventsPerBar = 4
    package static let maximumUpperPercussionTailEventsPerBar = 4
    package static let maximumModalPercussionEventsPerBar = 2
    package static let maximumInstrumentArchitecturesPerBar = 3
    package static let maximumInstrumentAssignmentsPerArchitecture = 6
    package static let maximumInstrumentEventsPerBar = 64
    package static let maximumUpperTimingEventsPerBar = 64

    package let schemaVersion: Int
    package let planFingerprint: String
    package let graphFingerprint: String
    package let symbolic: AutonomousSymbolicEvidence
    package let hardGates: AutonomousHardGateEvidence
    package let fullMix: AutonomousFullMixEvidence
    package let crossPhraseTransition: CrossPhraseTransitionEvidence
    package let sourceMaskingBarCount: Int
    package let masking: [AutonomousMaskingBarEvidence]
    package let sourceStemBarCount: Int
    package let stems: [AutonomousStemBarEvidence]
    package let sourceAutomaticMixBarCount: Int
    package let automaticMix: [AutonomousAutomaticMixEvidence]
    package let sourceKickSyntaxBarCount: Int
    package let kickSyntax: [AutonomousKickSyntaxBarEvidence]
    package let sourceFoundationRhythmBarCount: Int
    package let foundationRhythm: [AutonomousFoundationRhythmBarEvidence]
    package let climaxArc: AutonomousClimaxArcEvidence
    package let sourceGroovePulseBarCount: Int
    package let groovePulse: [AutonomousGroovePulseBarEvidence]
    package let sourceClosedHatBarCount: Int
    package let closedHat: [AutonomousClosedHatBarEvidence]
    package let sourceUpperPercussionTailBarCount: Int
    package let upperPercussionTail:
        [AutonomousUpperPercussionTailBarEvidence]
    package let sourceModalPercussionBarCount: Int
    package let modalPercussion: [AutonomousModalPercussionBarEvidence]
    package let sourceInstrumentBarCount: Int
    package let instruments: [AutonomousInstrumentBarEvidence]
    package let sourcePercussionEchoTextureBarCount: Int
    package let percussionEchoTexture:
        [AutonomousPercussionEchoTextureBarEvidence]
    package let sourcePhraseCompositionBarCount: Int
    package let phraseComposition: [AutonomousPhraseCompositionBarEvidence]
    package let sourcePulseEchoDriveBarCount: Int
    package let pulseEchoDrive: [AutonomousPulseEchoDriveBarEvidence]
    package let sourceSpatialFDNBarCount: Int
    package let spatialFDN: [AutonomousSpatialFDNBarEvidence]
    package let sourceUpperTimingBarCount: Int
    package let upperTiming: [AutonomousUpperTimingBarEvidence]
    package let graph: AutonomousGraphEvidence
    package let routeContinuation: AutonomousRouteContinuationEvidence
    package let incomingLiveMasterRevision: Int
    package let outgoingLiveMasterRevision: Int
    package let incomingLiveMasterTrimDB: Double
    package let incomingLiveMasterCleanWindowCount: Int
    package let outgoingLiveMasterCleanWindowCount: Int
    package let incomingLiveMasterStateFingerprint: String
    package let outgoingLiveMasterStateFingerprint: String
    package let liveObservationFingerprint: String?
    package let liveProposalFingerprint: String?
    package let liveProposalOutcome: LiveFeedbackProposalOutcome
    package let requestedLiveMasterTrimDB: Double
    package let appliedLiveMasterTrimDB: Double
    package let liveMasterGain: Double
    package let preLiveMasterPCMFingerprint: String
    package let postLiveMasterPCMFingerprint: String
    package let liveMasterScalingMatches: Bool
    package let liveEarliestEligibleFutureSample: Int64?
    package let liveAppliedFutureSample: Int64?
    package let liveProposalBindingMatches: Bool
    /// Aggregate over the exact graph-input remainder. This diagnoses whether
    /// a deficit existed before the generated topology.
    package let preGraphUpperTimbreEvidence: UpperTimbreEvidence
    /// Aggregate over the post-graph remainder. Existing playback hard gates
    /// continue to use this observation.
    package let postGraphUpperTimbreEvidence: UpperTimbreEvidence

    package init(
        planFingerprint: String,
        graphFingerprint: String,
        symbolic: AutonomousSymbolicEvidence,
        hardGates: AutonomousHardGateEvidence,
        fullMix: AutonomousFullMixEvidence,
        crossPhraseTransition: CrossPhraseTransitionEvidence,
        masking: [AutonomousMaskingBarEvidence],
        stems: [AutonomousStemBarEvidence],
        automaticMix: [AutonomousAutomaticMixEvidence],
        kickSyntax: [AutonomousKickSyntaxBarEvidence],
        foundationRhythm: [AutonomousFoundationRhythmBarEvidence],
        climaxArc: AutonomousClimaxArcEvidence,
        groovePulse: [AutonomousGroovePulseBarEvidence],
        closedHat: [AutonomousClosedHatBarEvidence] = [],
        upperPercussionTail:
            [AutonomousUpperPercussionTailBarEvidence] = [],
        modalPercussion: [AutonomousModalPercussionBarEvidence],
        instruments: [AutonomousInstrumentBarEvidence],
        percussionEchoTexture: [AutonomousPercussionEchoTextureBarEvidence],
        phraseComposition: [AutonomousPhraseCompositionBarEvidence],
        pulseEchoDrive: [AutonomousPulseEchoDriveBarEvidence],
        spatialFDN: [AutonomousSpatialFDNBarEvidence],
        upperTiming: [AutonomousUpperTimingBarEvidence],
        graph: AutonomousGraphEvidence,
        routeContinuation: AutonomousRouteContinuationEvidence,
        incomingLiveMasterRevision: Int,
        outgoingLiveMasterRevision: Int,
        incomingLiveMasterTrimDB: Double,
        incomingLiveMasterCleanWindowCount: Int,
        outgoingLiveMasterCleanWindowCount: Int,
        incomingLiveMasterStateFingerprint: String,
        outgoingLiveMasterStateFingerprint: String,
        liveObservationFingerprint: String?,
        liveProposalFingerprint: String?,
        liveProposalOutcome: LiveFeedbackProposalOutcome,
        requestedLiveMasterTrimDB: Double,
        appliedLiveMasterTrimDB: Double,
        liveMasterGain: Double,
        preLiveMasterPCMFingerprint: String,
        postLiveMasterPCMFingerprint: String,
        liveMasterScalingMatches: Bool,
        liveEarliestEligibleFutureSample: Int64?,
        liveAppliedFutureSample: Int64?,
        liveProposalBindingMatches: Bool,
        preGraphUpperTimbreEvidence: UpperTimbreEvidence,
        postGraphUpperTimbreEvidence: UpperTimbreEvidence
    ) {
        schemaVersion = Self.schemaVersion
        self.planFingerprint = planFingerprint
        self.graphFingerprint = graphFingerprint
        self.symbolic = symbolic
        self.hardGates = hardGates
        self.fullMix = fullMix
        self.crossPhraseTransition = crossPhraseTransition
        sourceMaskingBarCount = masking.count
        self.masking = Array(masking.prefix(Self.maximumBarCount))
        sourceStemBarCount = stems.count
        self.stems = Array(stems.prefix(Self.maximumBarCount))
        sourceAutomaticMixBarCount = automaticMix.count
        self.automaticMix = Array(automaticMix.prefix(Self.maximumBarCount))
        sourceKickSyntaxBarCount = kickSyntax.count
        self.kickSyntax = Array(kickSyntax.prefix(Self.maximumBarCount))
        sourceFoundationRhythmBarCount = foundationRhythm.count
        self.foundationRhythm = Array(
            foundationRhythm.prefix(Self.maximumBarCount)
        )
        self.climaxArc = climaxArc
        sourceGroovePulseBarCount = groovePulse.count
        self.groovePulse = Array(groovePulse.prefix(Self.maximumBarCount))
        sourceClosedHatBarCount = closedHat.count
        self.closedHat = Array(closedHat.prefix(Self.maximumBarCount))
        sourceUpperPercussionTailBarCount = upperPercussionTail.count
        self.upperPercussionTail = Array(
            upperPercussionTail.prefix(Self.maximumBarCount)
        )
        sourceModalPercussionBarCount = modalPercussion.count
        self.modalPercussion = Array(
            modalPercussion.prefix(Self.maximumBarCount)
        )
        sourceInstrumentBarCount = instruments.count
        self.instruments = Array(instruments.prefix(Self.maximumBarCount))
        sourcePercussionEchoTextureBarCount = percussionEchoTexture.count
        self.percussionEchoTexture = Array(
            percussionEchoTexture.prefix(Self.maximumBarCount)
        )
        sourcePhraseCompositionBarCount = phraseComposition.count
        self.phraseComposition = Array(
            phraseComposition.prefix(Self.maximumBarCount)
        )
        sourcePulseEchoDriveBarCount = pulseEchoDrive.count
        self.pulseEchoDrive = Array(pulseEchoDrive.prefix(Self.maximumBarCount))
        sourceSpatialFDNBarCount = spatialFDN.count
        self.spatialFDN = Array(spatialFDN.prefix(Self.maximumBarCount))
        sourceUpperTimingBarCount = upperTiming.count
        self.upperTiming = Array(upperTiming.prefix(Self.maximumBarCount))
        self.graph = graph
        self.routeContinuation = routeContinuation
        self.incomingLiveMasterRevision = incomingLiveMasterRevision
        self.outgoingLiveMasterRevision = outgoingLiveMasterRevision
        self.incomingLiveMasterTrimDB = incomingLiveMasterTrimDB
        self.incomingLiveMasterCleanWindowCount =
            incomingLiveMasterCleanWindowCount
        self.outgoingLiveMasterCleanWindowCount =
            outgoingLiveMasterCleanWindowCount
        self.incomingLiveMasterStateFingerprint =
            incomingLiveMasterStateFingerprint
        self.outgoingLiveMasterStateFingerprint =
            outgoingLiveMasterStateFingerprint
        self.liveObservationFingerprint = liveObservationFingerprint
        self.liveProposalFingerprint = liveProposalFingerprint
        self.liveProposalOutcome = liveProposalOutcome
        self.requestedLiveMasterTrimDB = requestedLiveMasterTrimDB
        self.appliedLiveMasterTrimDB = appliedLiveMasterTrimDB
        self.liveMasterGain = liveMasterGain
        self.preLiveMasterPCMFingerprint = preLiveMasterPCMFingerprint
        self.postLiveMasterPCMFingerprint = postLiveMasterPCMFingerprint
        self.liveMasterScalingMatches = liveMasterScalingMatches
        self.liveEarliestEligibleFutureSample =
            liveEarliestEligibleFutureSample
        self.liveAppliedFutureSample = liveAppliedFutureSample
        self.liveProposalBindingMatches = liveProposalBindingMatches
        self.preGraphUpperTimbreEvidence = preGraphUpperTimbreEvidence
        self.postGraphUpperTimbreEvidence = postGraphUpperTimbreEvidence
    }

    package static func make(
        plan: AutonomousPhrasePlan,
        graph: DSPGraphPlan,
        planFingerprint: String,
        graphFingerprint: String,
        blocks: [RenderBlock],
        audioPreflight: PhraseAudioPreflight,
        crossPhraseTransition: CrossPhraseTransitionEvidence,
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
        incomingLiveMasterState: LiveMasterHeadroomContinuationState,
        outgoingLiveMasterState: LiveMasterHeadroomContinuationState,
        liveProposal: LiveMasterHeadroomProposal?,
        liveProposalOutcome: LiveFeedbackProposalOutcome,
        liveTargetStartSample: Int64?,
        incomingDramaticDebts: [SessionDramaticDebt],
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
            boundsValid: completeInputs
        )
        let hardGates = AutonomousHardGateEvidence(
            symbolicValid: plan.interest.valid,
            graphValid: graphValidation.valid,
            audioSafetyValid: audioPreflight.safetyValid &&
                crossPhraseTransition.hardGateValid,
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
                targetKickOverFoundationDB: block.automaticMix.targetKickOverFoundationDB,
                sourceKickRMS: block.automaticMix.sourceKickRMS,
                sourceKickActiveRMS: block.automaticMix.sourceKickActiveRMS
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
            let withheldContextMatches: Bool
            if role != .withheld {
                withheldContextMatches = true
            } else if block.resolvedPerformance.climaxHang != nil {
                withheldContextMatches =
                    block.resolvedPerformance.groovePulses.map(\.step) ==
                        ClimaxHangContract.preHangWeakPulseSteps &&
                    block.resolvedPerformance.ensemble.events.allSatisfy {
                        $0.step < ClimaxHangContract.startStep
                    } &&
                    block.resolvedPerformance.percussionEchoTexture?.relation ==
                        .anticipationSwell
            } else {
                withheldContextMatches =
                    block.resolvedPerformance.groovePulses.map(\.step) ==
                        KickSyntaxResolver.canonicalWeakPulseSteps &&
                    block.resolvedPerformance.ensemble.events.contains {
                        $0.voice == .motif
                    } &&
                    block.instrumentRenderEvidence.contains { architecture in
                        architecture.assignments.contains { $0.use == .motif }
                    }
            }
            let syntaxAuthorizationMatches = role == .grounded || (
                plan.kind == .energyRelease && !plan.paidDebtIDs.isEmpty
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
                mix.sourceDynamics.morphologyScoreHash ==
                    KickSourceDynamicsContract.morphologyScoreHash(
                        block.resolvedPerformance.kickMorphology
                    ) &&
                mix.sourceDynamics.morphologyBound &&
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
                sourceDynamics: AutonomousKickSourceDynamicsEvidence(
                    render: mix.sourceDynamics
                ),
                detectorToAudibleScaleMatches:
                    mix.detectorToAudibleScaleMatches,
                renderPassesMatch: block.kickRenderPassesMatch,
                bindingValid: bindingValid
            ))
        }
        let foundationRhythm = boundedBlocks.enumerated().map { index, block in
            let resolved = block.resolvedPerformance
            let render = block.foundationRhythmRenderEvidence
            let scoreBassEvents = resolved.ensemble.events.filter {
                $0.voice == .bass
            }
            let scoreBassSteps = scoreBassEvents.map(\.step)
            let scoreMask = stepMaskAllowingDuplicates(scoreBassSteps)
            let stepFrames = Double(block.left.count) / 16.0
            let expectedStartFrames = scoreBassEvents.map { event in
                let offset = VoiceRenderer.timingOffsetInSteps(
                    for: .bass,
                    step: event.step,
                    dna: plan.dna
                )
                return Int(((Double(event.step) + offset) * stepFrames).rounded())
            }
            let planBarMatches = plan.resolvedBars.indices.contains(index) &&
                plan.resolvedBars[index] == resolved &&
                resolved.performance.bar == block.bar
            let assignment = block.synthPerformance.foundationInstrument
            let preKickPocketBindingValid: Bool = {
                let score = FoundationPreKickPocketResolver.articulation(
                    in: resolved
                )
                let pocket = render.preKickPocket
                guard let score else { return pocket == .neutral }
                guard resolved.ensemble.events.indices.contains(
                        score.scoreEventIndex
                      ) else { return false }
                let event = resolved.ensemble.events[score.scoreEventIndex]
                let offset = VoiceRenderer.timingOffsetInSteps(
                    for: event.voice,
                    step: event.step,
                    dna: plan.dna
                )
                let eventStartFrame = Int((
                    (Double(event.step) + offset) * stepFrames
                ).rounded())
                let naturalFrameCount = min(
                    max(1, Int((sampleRate * (
                        0.16 + assignment.automation.shape * 0.18
                    )).rounded())),
                    max(0, block.left.count - eventStartFrame)
                )
                let kickOffset = VoiceRenderer.timingOffsetInSteps(
                    for: .kick,
                    step: score.kickStep,
                    dna: plan.dna
                )
                let kickFrame = Int(((
                    Double(score.kickStep) + kickOffset
                ) * stepFrames).rounded())
                let releaseStartFrame = Int(((
                    score.releaseStartStep + kickOffset
                ) * stepFrames).rounded())
                let releaseEndFrame = Int(((
                    score.releaseEndStep + kickOffset
                ) * stepFrames).rounded())
                return event.voice == .bass &&
                    event.step == score.bassStep &&
                    pocket.relation == score.relation &&
                    pocket.scoreEventIndex == score.scoreEventIndex &&
                    pocket.bassStep == score.bassStep &&
                    pocket.kickStep == score.kickStep &&
                    pocket.eventStartFrame == eventStartFrame &&
                    pocket.naturalEndFrame == eventStartFrame +
                        naturalFrameCount &&
                    pocket.releaseStartFrame == releaseStartFrame &&
                    pocket.releaseEndFrame == releaseEndFrame &&
                    pocket.kickFrame == kickFrame &&
                    pocket.applied && pocket.finite
            }()
            let bindingValid = planBarMatches &&
                block.section == resolved.performance.section &&
                block.left.count == block.right.count &&
                render.bar == block.bar &&
                render.relation == resolved.foundationRhythmicRelation &&
                render.sampleRate == sampleRate &&
                render.renderedFrameCount == block.left.count &&
                render.renderedBassEventCount == scoreBassEvents.count &&
                (scoreMask.map { render.renderedBassStepMask == $0 } ?? false) &&
                render.renderedStartFrames == expectedStartFrames &&
                assignment.use == .foundationBass &&
                assignment.isValid &&
                preKickPocketBindingValid &&
                block.foundationRhythmRenderPassesMatch
            return AutonomousFoundationRhythmBarEvidence(
                bar: block.bar,
                relation: resolved.foundationRhythmicRelation,
                pairPhase: FoundationRhythmicRelationContract.pairPhase(
                    absoluteBar: block.bar
                ),
                scoreBassEventCount: scoreBassEvents.count,
                scoreBassStepMask: scoreMask ?? 0,
                renderedBassEventCount: render.renderedBassEventCount,
                renderedBassStepMask: render.renderedBassStepMask,
                renderedFrameCount: render.renderedFrameCount,
                renderedStartFrameFingerprint:
                    AutonomousFoundationRhythmBarEvidence
                        .startFrameFingerprint(render.renderedStartFrames),
                dryFoundationSampleHash: render.dryFoundationSampleHash,
                peak: render.peak,
                rms: render.rms,
                bassPluckAssigned: assignment.patch == .bassPluck,
                preKickPocket: AutonomousFoundationPreKickPocketEvidence(
                    render: render.preKickPocket
                ),
                renderPassesMatch: block.foundationRhythmRenderPassesMatch,
                bindingValid: bindingValid,
                finite: render.finite
            )
        }
        let climaxArc = makeClimaxArcEvidence(
            plan: plan,
            incomingDramaticDebts: incomingDramaticDebts,
            kickSyntax: kickSyntax,
            blocks: boundedBlocks,
            sampleRate: sampleRate
        )
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
        let upperPercussionTail = boundedBlocks.map { block in
            let resolved = block.resolvedPerformance
            let score = resolved.upperPercussionTailArticulations
            let rendered = block.upperPercussionTailRenderEvidence
            let planBarMatches = plan.resolvedBars.first {
                $0.performance.bar == block.bar
            } == resolved
            let replayed = UpperPercussionTailResolver.articulations(
                from: resolved.ensemble,
                phraseKind: plan.kind,
                performanceCharacter: resolved.performanceCharacter
            )
            let matched = rendered.compactMap {
                evidence -> AutonomousUpperPercussionTailEventEvidence? in
                guard resolved.ensemble.events.indices.contains(
                    evidence.scoreEventIndex
                ), let articulation = score.first(where: {
                    $0.scoreEventIndex == evidence.scoreEventIndex
                }) else {
                    return nil
                }
                let event = resolved.ensemble.events[evidence.scoreEventIndex]
                let expectedTiming = VoiceRenderer.timingOffsetInSteps(
                    for: event.voice,
                    step: event.step,
                    dna: block.sceneDNA
                )
                guard articulation.voice == event.voice,
                      articulation.step == event.step,
                      evidence.voice == event.voice,
                      evidence.step == event.step,
                      evidence.role == articulation.role,
                      evidence.body == articulation.body,
                      evidence.eventIntensity == event.intensity,
                      evidence.timingOffsetInSteps == expectedTiming,
                      evidence.relocated == event.relocated else {
                    return nil
                }
                return AutonomousUpperPercussionTailEventEvidence(evidence)
            }.sorted { $0.scoreEventIndex < $1.scoreEventIndex }
            let bindingValid = planBarMatches && replayed == score &&
                block.section == resolved.performance.section &&
                score.count == rendered.count && matched.count == score.count &&
                block.upperPercussionTailRenderPassesMatch
            return AutonomousUpperPercussionTailBarEvidence(
                bar: block.bar,
                focusRole: resolved.ensemble.focusRole.rawValue,
                intentionalPileup: resolved.ensemble.intentionalPileup,
                sourceScoreEventCount: score.count,
                sourceRenderEventCount: rendered.count,
                renderPassesMatch:
                    block.upperPercussionTailRenderPassesMatch,
                bindingValid: bindingValid,
                events: matched
            )
        }
        let modalPercussion = makeModalPercussionEvidence(
            blocks: boundedBlocks,
            planBars: plan.resolvedBars,
            sampleRate: sampleRate
        )
        let instruments = boundedBlocks.map { block in
            AutonomousInstrumentBarEvidence(
                bar: block.bar,
                evidence: block.instrumentRenderEvidence
            )
        }
        let percussionEchoTexture = boundedBlocks.map { block in
            let evidence = block.percussionEchoTextureRenderEvidence
            let resolved = block.resolvedPerformance
            let articulation = resolved.percussionEchoTexture
            let eligibleSteps = Array(Set(
                PercussionEchoTextureResolver.eligibleSourceEvents(
                    in: resolved.ensemble
                ).map(\.step)
            )).sorted()
            let eligibleMask = kickStepMask(eligibleSteps)
            let planBarMatches = plan.resolvedBars.first {
                $0.performance.bar == block.bar
            } == resolved
            let bindingValid = eligibleMask != nil && planBarMatches &&
                block.section == resolved.performance.section &&
                evidence.active == (articulation != nil) &&
                evidence.relation == articulation?.relation &&
                evidence.bpm == plan.scene.bpm &&
                evidence.sampleRate == sampleRate &&
                evidence.renderedFrameCount == block.left.count &&
                evidence.renderedFrameCount == block.right.count &&
                evidence.inputStep == (articulation?.inputStep ?? -1) &&
                evidence.outputStartStep ==
                    (articulation?.outputStartStep ?? -1) &&
                evidence.outputEndStep ==
                    (articulation?.outputEndStep ?? -1) &&
                block.percussionEchoTextureRenderPassesMatch
            return AutonomousPercussionEchoTextureBarEvidence(
                evidence,
                bar: block.bar,
                performanceCharacter: resolved.performanceCharacter,
                arrangementGesture: resolved.arrangementGesture,
                kickSyntaxRole: resolved.kickSyntaxRole,
                eligibleSourceStepMask: eligibleMask ?? 0,
                renderPassesMatch:
                    block.percussionEchoTextureRenderPassesMatch,
                bindingValid: bindingValid
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
        let expectedSpatialFDNConfiguration = FeedbackDelayNetworkConfiguration(
            scene: plan.scene,
            sampleRate: sampleRate,
            phraseKind: plan.kind
        )
        let spatialFDN = makeSpatialFDNEvidence(
            blocks: boundedBlocks,
            planBars: plan.resolvedBars,
            expectedConfiguration: expectedSpatialFDNConfiguration,
            sampleRate: sampleRate
        )
        let phraseComposition = boundedBlocks.map {
            AutonomousPhraseCompositionBarEvidence(block: $0)
        }
        let upperTiming = makeUpperTimingEvidence(
            blocks: boundedBlocks,
            planBPM: plan.scene.bpm,
            routeSampleRate: sampleRate
        )
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
        let liveInputs = boundedBlocks.map {
            AutonomousLiveMasterRenderValidationInput(
                left: $0.left,
                right: $0.right,
                evidence: $0.liveMasterTrimRenderEvidence
            )
        }
        guard let liveEvidence = validatedLiveMasterEvidence(
            inputs: liveInputs,
            outgoingState: outgoingLiveMasterState,
            cancellationRequested: cancellationRequested
        ) else { return nil }
        guard !cancellationRequested() else { return nil }
        let liveProposalBindingMatches: Bool
        if let liveProposal {
            let proposalMatchesIncoming = liveProposal.isStructurallyValid &&
                liveProposal.incomingRevision == incomingLiveMasterState.revision &&
                liveProposal.incomingStateFingerprint ==
                    incomingLiveMasterState.fingerprint &&
                liveProposal.routeGeneration == routeGeneration &&
                liveProposal.proposedTrimDB == liveEvidence.requestedTrimDB
            if liveProposalOutcome == .unavailable {
                liveProposalBindingMatches = proposalMatchesIncoming &&
                    outgoingLiveMasterState == incomingLiveMasterState
            } else {
                liveProposalBindingMatches = proposalMatchesIncoming &&
                    outgoingLiveMasterState.lastProposalFingerprint ==
                        liveProposal.fingerprint &&
                    outgoingLiveMasterState.lastObservationFingerprint ==
                        liveProposal.observationFingerprint &&
                    outgoingLiveMasterState.earliestEligibleFutureSample ==
                        liveProposal.earliestEligibleFutureSample
            }
        } else {
            liveProposalBindingMatches = liveProposalOutcome == .hold &&
                outgoingLiveMasterState == incomingLiveMasterState
        }
        return AutonomousCandidateEvaluationVector(
            planFingerprint: planFingerprint,
            graphFingerprint: graphFingerprint,
            symbolic: symbolic,
            hardGates: hardGates,
            fullMix: fullMix,
            crossPhraseTransition: crossPhraseTransition,
            masking: masking,
            stems: stems,
            automaticMix: automaticMix,
            kickSyntax: kickSyntax,
            foundationRhythm: foundationRhythm,
            climaxArc: climaxArc,
            groovePulse: groovePulse,
            closedHat: closedHat,
            upperPercussionTail: upperPercussionTail,
            modalPercussion: modalPercussion,
            instruments: instruments,
            percussionEchoTexture: percussionEchoTexture,
            phraseComposition: phraseComposition,
            pulseEchoDrive: pulseEchoDrive,
            spatialFDN: spatialFDN,
            upperTiming: upperTiming,
            graph: graphEvidence,
            routeContinuation: route,
            incomingLiveMasterRevision: incomingLiveMasterState.revision,
            outgoingLiveMasterRevision: outgoingLiveMasterState.revision,
            incomingLiveMasterTrimDB:
                incomingLiveMasterState.committedTrimDB,
            incomingLiveMasterCleanWindowCount:
                incomingLiveMasterState.consecutiveCleanWindows,
            outgoingLiveMasterCleanWindowCount:
                outgoingLiveMasterState.consecutiveCleanWindows,
            incomingLiveMasterStateFingerprint:
                incomingLiveMasterState.fingerprint,
            outgoingLiveMasterStateFingerprint:
                outgoingLiveMasterState.fingerprint,
            liveObservationFingerprint: liveProposal?.observationFingerprint,
            liveProposalFingerprint: liveProposal?.fingerprint,
            liveProposalOutcome: liveProposalOutcome,
            requestedLiveMasterTrimDB: liveEvidence.requestedTrimDB,
            appliedLiveMasterTrimDB: liveEvidence.appliedTrimDB,
            liveMasterGain: liveEvidence.appliedGain,
            preLiveMasterPCMFingerprint:
                liveEvidence.preTrimPCMFingerprint,
            postLiveMasterPCMFingerprint:
                liveEvidence.postTrimPCMFingerprint,
            liveMasterScalingMatches:
                liveEvidence.validatedBlockCount == boundedBlocks.count,
            liveEarliestEligibleFutureSample:
                liveProposal?.earliestEligibleFutureSample,
            liveAppliedFutureSample: liveTargetStartSample,
            liveProposalBindingMatches: liveProposalBindingMatches,
            preGraphUpperTimbreEvidence: preGraphUpperTimbreEvidence,
            postGraphUpperTimbreEvidence: upperTimbreEvidence
        )
    }

    @inline(never)
    private static func makeModalPercussionEvidence(
        blocks: [RenderBlock],
        planBars: [ResolvedPerformanceBar],
        sampleRate: Double
    ) -> [AutonomousModalPercussionBarEvidence] {
        var result: [AutonomousModalPercussionBarEvidence] = []
        result.reserveCapacity(blocks.count)
        for (index, block) in blocks.enumerated() {
            let resolved = block.resolvedPerformance
            let score = resolved.modalPercussionArticulations
            let render = block.modalPercussionRenderEvidence
            let renderedEvents = render.events
            let tunedTomIndices = resolved.ensemble.events.enumerated()
                .filter { $0.element.voice == .tunedTom }
                .map(\.offset)
            let scoreIndices = score.map(\.scoreEventIndex)
            let renderedIndices = renderedEvents.map {
                $0.articulation.scoreEventIndex
            }
            let planBarMatches = planBars.indices.contains(index) &&
                planBars[index] == resolved &&
                planBars[index].performance.bar == block.bar
            let barBindingValid = planBarMatches &&
                block.section == resolved.performance.section &&
                render.bar == block.bar && render.sampleRate == sampleRate &&
                render.renderedFrameCount == block.left.count &&
                block.left.count == block.right.count &&
                scoreIndices == tunedTomIndices &&
                renderedIndices == scoreIndices &&
                render.dryBarSampleHash == block.dryModalPercussionSampleHash &&
                block.modalPercussionRenderPassesMatch &&
                block.modalPercussionFoundationRoutingValid
            let events = renderedEvents.compactMap {
                evidence -> AutonomousModalPercussionEventEvidence? in
                let index = evidence.articulation.scoreEventIndex
                guard score.filter({ $0.scoreEventIndex == index }).count == 1,
                      let articulation = score.first(where: {
                          $0.scoreEventIndex == index
                      }),
                      resolved.ensemble.events.indices.contains(index) else {
                    return nil
                }
                let scoreEvent = resolved.ensemble.events[index]
                let scoreBindingValid = barBindingValid &&
                    scoreEvent.voice == .tunedTom &&
                    scoreEvent.step == articulation.step &&
                    scoreEvent.intensity == articulation.eventIntensity &&
                    articulation.use == .foundationCompanion &&
                    evidence.articulation == articulation &&
                    evidence.requestedFundamentalHz ==
                        articulation.fundamentalHz &&
                    evidence.appliedFundamentalHz ==
                        articulation.fundamentalHz &&
                    evidence.modeCount == ModalPercussionVoice.modeCount &&
                    evidence.stable && evidence.capacityValid
                return AutonomousModalPercussionEventEvidence(
                    scoreEventIndex: articulation.scoreEventIndex,
                    step: articulation.step,
                    use: articulation.use.rawValue,
                    modalIdentity: articulation.modalIdentity.rawValue,
                    modalDegree: articulation.modalDegree,
                    octave: articulation.octave,
                    requestedFundamentalHz:
                        evidence.requestedFundamentalHz,
                    appliedFundamentalHz: evidence.appliedFundamentalHz,
                    excitation: articulation.excitation,
                    damping: articulation.damping,
                    brightness: articulation.brightness,
                    inharmonicity: articulation.inharmonicity,
                    intensity: articulation.eventIntensity,
                    modeCount: evidence.modeCount,
                    modeRatioFingerprint: evidence.modeRatioFingerprint,
                    minimumModeFrequencyHz:
                        evidence.minimumModeFrequencyHz,
                    maximumModeFrequencyHz:
                        evidence.maximumModeFrequencyHz,
                    maximumPoleRadius: evidence.maximumPoleRadius,
                    excitationFingerprint: evidence.excitationFingerprint,
                    drySampleHash: evidence.drySampleHash,
                    renderedFrameCount: evidence.renderedFrameCount,
                    nonzeroSampleCount: evidence.nonzeroSampleCount,
                    peak: evidence.peak,
                    rms: evidence.rms,
                    crestFactor: evidence.crestFactor,
                    attackRMS: evidence.attackRMS,
                    bodyRMS: evidence.bodyRMS,
                    tailRMS: evidence.tailRMS,
                    tailToBodyDB: evidence.tailToBodyDB,
                    spectralCentroidHz: evidence.spectralCentroidHz,
                    incomingVoiceStateFingerprint:
                        evidence.incomingVoiceStateFingerprint,
                    outgoingVoiceStateFingerprint:
                        evidence.outgoingVoiceStateFingerprint,
                    finite: evidence.finite,
                    stable: evidence.stable,
                    capacityValid: evidence.capacityValid,
                    scoreBindingValid: scoreBindingValid,
                    routeBindingValid: evidence.routeBindingValid &&
                        render.sampleRate == sampleRate
                )
            }.sorted { $0.scoreEventIndex < $1.scoreEventIndex }
            result.append(AutonomousModalPercussionBarEvidence(
                bar: block.bar,
                sourceScoreEventCount: score.count,
                sourceRenderEventCount: renderedEvents.count,
                use: ModalPercussionUse.foundationCompanion.rawValue,
                incomingStateFingerprint: render.incomingStateFingerprint,
                outgoingStateFingerprint: render.outgoingStateFingerprint,
                dryBarSampleHash: render.dryBarSampleHash,
                activeIncomingVoiceCount: render.activeIncomingVoiceCount,
                activeOutgoingVoiceCount: render.activeOutgoingVoiceCount,
                continuationRendered: render.continuationRendered,
                renderPassesMatch:
                    block.modalPercussionRenderPassesMatch,
                foundationRoutingValid: barBindingValid,
                events: events
            ))
        }
        return result
    }

    /// Keeps the spatial-FDN binding audit out of the already large candidate
    /// vector constructor. Apart from making this evidence easier to inspect,
    /// the explicit frame prevents Swift's generic metadata lookup for
    /// `contains(where:)` from exhausting the testing worker's bounded stack.
    @inline(never)
    private static func makeSpatialFDNEvidence(
        blocks: [RenderBlock],
        planBars: [ResolvedPerformanceBar],
        expectedConfiguration: FeedbackDelayNetworkConfiguration,
        sampleRate: Double
    ) -> [AutonomousSpatialFDNBarEvidence] {
        var result: [AutonomousSpatialFDNBarEvidence] = []
        result.reserveCapacity(blocks.count)
        for block in blocks {
            result.append(AutonomousSpatialFDNBarEvidence(
                block.spatialFDNRenderEvidence,
                bindingValid: spatialFDNBindingIsValid(
                    block: block,
                    planBars: planBars,
                    expectedConfiguration: expectedConfiguration,
                    sampleRate: sampleRate
                )
            ))
        }
        return result
    }

    @inline(never)
    private static func spatialFDNBindingIsValid(
        block: RenderBlock,
        planBars: [ResolvedPerformanceBar],
        expectedConfiguration: FeedbackDelayNetworkConfiguration,
        sampleRate: Double
    ) -> Bool {
        let evidence = block.spatialFDNRenderEvidence
        let spatial = block.resolvedPerformance.spatialContrast
        var planBarMatches = false
        for planBar in planBars where planBar.performance.bar == block.bar {
            planBarMatches = planBar == block.resolvedPerformance
            break
        }
        var effectMatches = false
        for effect in block.effects {
            if effect.kind == .spatialFDN &&
                effect.amount == evidence.wetGain &&
                effect.active == (evidence.activeWetFrameCount > 0) {
                effectMatches = true
                break
            }
        }
        let activeExpectedConfiguration =
            expectedConfiguration.retainingGeometry(
                roomScale: evidence.roomScale
            )
        return planBarMatches &&
            evidence.bar == block.bar &&
            evidence.sampleRate == sampleRate &&
            evidence.renderedFrameCount == block.left.count &&
            evidence.renderedFrameCount == block.right.count &&
            evidence.lineCount == FeedbackDelayNetworkConfiguration.lineCount &&
            evidence.requestedRoomScale == expectedConfiguration.roomScale &&
            evidence.delayFrameCounts ==
                activeExpectedConfiguration.delayFrameCounts &&
            (evidence.geometryRetained ||
                evidence.roomScale == evidence.requestedRoomScale) &&
            evidence.decayTimeSeconds ==
                activeExpectedConfiguration.decayTimeSeconds &&
            evidence.dampingHz == activeExpectedConfiguration.dampingHz &&
            evidence.maximumFeedbackGain ==
                activeExpectedConfiguration.maximumFeedbackGain &&
            evidence.synthSendGain ==
                activeExpectedConfiguration.synthSendGain &&
            evidence.percussionSendGain ==
                activeExpectedConfiguration.percussionSendGain &&
            evidence.wetGain == activeExpectedConfiguration.wetGain &&
            evidence.spatialDepthPosition == spatial.depthPosition &&
            evidence.carrierVoice == spatial.carrierVoice &&
            evidence.carrierStep == spatial.carrierStep &&
            evidence.scoreReverbSend == spatial.reverbSend &&
            evidence.scoreHighPassHz == spatial.highPassHz &&
            evidence.scoreLowPassHz == spatial.lowPassHz && effectMatches
    }

    @inline(never)
    private static func makeUpperTimingEvidence(
        blocks: [RenderBlock],
        planBPM: Double,
        routeSampleRate: Double
    ) -> [AutonomousUpperTimingBarEvidence] {
        var result: [AutonomousUpperTimingBarEvidence] = []
        result.reserveCapacity(blocks.count)
        for block in blocks {
            result.append(makeUpperTimingEvidence(
                block: block,
                planBPM: planBPM,
                routeSampleRate: routeSampleRate
            ))
        }
        return result
    }

    @inline(never)
    private static func makeClimaxArcEvidence(
        plan: AutonomousPhrasePlan,
        incomingDramaticDebts: [SessionDramaticDebt],
        kickSyntax: [AutonomousKickSyntaxBarEvidence],
        blocks: [RenderBlock],
        sampleRate: Double
    ) -> AutonomousClimaxArcEvidence {
        let activeHangBlocks = blocks.filter {
            $0.climaxHangRenderEvidence.active
        }
        let active = plan.kind == .energyRelease && !plan.paidDebtIDs.isEmpty
        guard active else {
            return .inactive(
                releaseStartBar: plan.startBar,
                bindingValid: activeHangBlocks.isEmpty
            )
        }
        let sourceDebtsAreBounded = incomingDramaticDebts.count <=
            AutonomousClimaxArcEvidence.maximumDebtCount
        let boundedIncomingDebts = Array(incomingDramaticDebts.prefix(
            AutonomousClimaxArcEvidence.maximumDebtCount + 1
        ))
        let paidDebts = boundedIncomingDebts.filter {
            plan.paidDebtIDs.contains($0.id)
        }
        let setupIndex = kickSyntax.indices.first { index in
            index <= kickSyntax.count - 4 &&
                kickSyntax[index].role == KickSyntaxRole.grounded.rawValue &&
                kickSyntax[index + 1].role == KickSyntaxRole.withheld.rawValue &&
                kickSyntax[index + 2].role == KickSyntaxRole.withheld.rawValue &&
                kickSyntax[index + 3].role == KickSyntaxRole.recovery.rawValue
        }
        let sourcesAreSupported = paidDebts.allSatisfy {
            $0.source == .contrast || $0.source == .majorBreak
        }
        let debtGeometryIsValid = paidDebts.allSatisfy {
            $0.id >= 0 && $0.openedAtBar >= 0 &&
                $0.openedAtBar < plan.startBar &&
                $0.dueByBar >= $0.openedAtBar
        }
        let exactDebtsMatch = sourceDebtsAreBounded &&
            paidDebts.map(\.id) == plan.paidDebtIDs &&
            paidDebts.count == incomingDramaticDebts.count
        let setupBar = setupIndex.map { kickSyntax[$0].bar }
        let secondWithheldBar = setupIndex.map { kickSyntax[$0 + 2].bar }
        let expectedHangBlock = activeHangBlocks.count == 1
            ? activeHangBlocks.first : nil
        let hangScoreBindingValid: Bool
        let hangEvidence: AutonomousClimaxHangEvidence
        if let expectedHangBlock {
            let score = expectedHangBlock.resolvedPerformance.climaxHang
            let texture = expectedHangBlock.resolvedPerformance
                .percussionEchoTexture
            let planBarMatches = plan.resolvedBars.contains {
                $0 == expectedHangBlock.resolvedPerformance &&
                    $0.performance.bar == expectedHangBlock.bar
            }
            hangScoreBindingValid =
                expectedHangBlock.bar == secondWithheldBar &&
                score == ClimaxHangArticulation() &&
                expectedHangBlock.resolvedPerformance.kickSyntaxRole ==
                    .withheld &&
                expectedHangBlock.resolvedPerformance.groovePulses.map(\.step) ==
                    ClimaxHangContract.preHangWeakPulseSteps &&
                expectedHangBlock.resolvedPerformance.ensemble.events
                    .allSatisfy { $0.step < ClimaxHangContract.startStep } &&
                texture?.relation == .anticipationSwell &&
                texture?.outputEndStep == ClimaxHangContract.startStep &&
                planBarMatches &&
                expectedHangBlock.climaxHangRenderEvidence.sampleRate ==
                    sampleRate &&
                expectedHangBlock.climaxHangRenderEvidence.renderedFrameCount ==
                    expectedHangBlock.left.count &&
                expectedHangBlock.left.count == expectedHangBlock.right.count
            hangEvidence = AutonomousClimaxHangEvidence(
                render: expectedHangBlock.climaxHangRenderEvidence,
                bar: expectedHangBlock.bar,
                postHangMatchesLiveMasterInput:
                    expectedHangBlock.climaxHangRenderEvidence
                        .postHangStereoSampleHash ==
                    expectedHangBlock.liveMasterTrimRenderEvidence
                        .preTrimStereoSampleHash,
                bindingValid: hangScoreBindingValid
            )
        } else {
            hangScoreBindingValid = false
            hangEvidence = .neutral
        }
        return AutonomousClimaxArcEvidence(
            relation: setupIndex == nil
                ? .dramaticDebtRelease : .dramaticDebtRecovery,
            paidDebtCount: paidDebts.count,
            contrastDebtCount: paidDebts.filter { $0.source == .contrast }.count,
            majorBreakDebtCount: paidDebts.filter { $0.source == .majorBreak }.count,
            sourceDebtFingerprint:
                AutonomousClimaxArcEvidence.debtFingerprint(paidDebts),
            earliestOpenedAtBar: paidDebts.map(\.openedAtBar).min(),
            latestOpenedAtBar: paidDebts.map(\.openedAtBar).max(),
            latestDueByBar: paidDebts.map(\.dueByBar).max(),
            releaseStartBar: plan.startBar,
            setupBar: setupBar,
            firstWithheldBar: setupIndex.map { kickSyntax[$0 + 1].bar },
            secondWithheldBar: secondWithheldBar,
            recoveryBar: setupIndex.map { kickSyntax[$0 + 3].bar },
            hang: setupIndex == nil ? .neutral : hangEvidence,
            bindingValid: sourcesAreSupported && debtGeometryIsValid &&
                exactDebtsMatch && (setupIndex == nil
                    ? activeHangBlocks.isEmpty
                    : hangScoreBindingValid)
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

    /// Foundation arbitration may retain more than one bass proposal at the
    /// same step. The count and ordered start-frame fingerprint preserve that
    /// multiplicity; this mask binds only the occupied sixteenth positions.
    private static func stepMaskAllowingDuplicates(_ steps: [Int]) -> UInt16? {
        var result: UInt16 = 0
        for step in steps {
            guard (0..<16).contains(step) else { return nil }
            result |= UInt16(1) << UInt16(step)
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

    private struct UpperTimingStatistics {
        let activeOffsetCount: Int
        let protectedRoleActiveOffsetCount: Int
        let anchorActiveOffsetCount: Int
        let anchorEventCount: Int
        let minimumOffset: Double
        let maximumOffset: Double
        let anchorMinimumOffset: Double
        let anchorMaximumOffset: Double
        let anchorFingerprint: String
        let shadowMinimumOffset: Double
        let shadowMaximumOffset: Double
        let responseMinimumOffset: Double
        let responseMaximumOffset: Double
    }

    @inline(never)
    private static func makeUpperTimingEvidence(
        block: RenderBlock,
        planBPM: Double,
        routeSampleRate: Double
    ) -> AutonomousUpperTimingBarEvidence {
        let renderEvidence = block.upperTimingRenderEvidence
        let scheduleUpperNotes = upperTimingScheduleEnabled(block)
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
        let scoreTuples = scoreUpperTimingTuples(
            scoreNotes,
            stepFrames: stepFrames,
            frameCount: renderEvidence.renderedFrameCount
        )
        let renderTuples = renderUpperTimingTuples(renderEvents)
        let eventGateFacts = upperTimingGateFacts(renderEvents)
        let actualGateFacts = upperNoteGateFacts(actualRenderEvidence)
        let scoreFingerprint = upperTimingFingerprint(scoreTuples)
        let renderFingerprint = upperTimingFingerprint(renderTuples)
        let appliedGateFingerprint = upperTimingAppliedGateFingerprint(
            eventGateFacts
        )
        let statistics = upperTimingStatistics(
            scoreNotes: scoreNotes,
            renderEvents: renderEvents
        )
        let anchorSignal = AutonomousUpperTimingRoleSignalEvidence(
            role: .anchor,
            evidence: renderEvidence.anchorSignal
        )
        let shadowSignal = AutonomousUpperTimingRoleSignalEvidence(
            role: .shadow,
            evidence: renderEvidence.shadowSignal
        )
        let responseSignal = AutonomousUpperTimingRoleSignalEvidence(
            role: .response,
            evidence: renderEvidence.responseSignal
        )
        let bindingValid = upperTimingBindingIsValid(
            block: block,
            renderEvidence: renderEvidence,
            planBPM: planBPM,
            routeSampleRate: routeSampleRate,
            sourceScoreNoteCount: sourceScoreNotes.count,
            scoreTupleCount: scoreTuples.count,
            renderTupleCount: renderTuples.count,
            scoreFingerprint: scoreFingerprint,
            renderFingerprint: renderFingerprint,
            eventGateFacts: eventGateFacts,
            actualGateFacts: actualGateFacts,
            anchorSignalCount: anchorSignal.eventCount,
            shadowSignalCount: shadowSignal.eventCount,
            responseSignalCount: responseSignal.eventCount
        )
        let finite = upperTimingIsFinite(
            planBPM: planBPM,
            routeSampleRate: routeSampleRate,
            scoreNotes: scoreNotes,
            renderEvents: renderEvents,
            signals: [anchorSignal, shadowSignal, responseSignal]
        )
        return AutonomousUpperTimingBarEvidence(
            bar: block.bar,
            chapter: block.resolvedPerformance.interlockChapter,
            relation: block.synthPerformance.upperTimingRelation,
            performanceCharacter:
                block.resolvedPerformance.performanceCharacter,
            bpm: planBPM,
            sampleRate: routeSampleRate,
            renderedFrameCount: renderEvidence.renderedFrameCount,
            sourceScoreNoteCount: sourceScoreNotes.count,
            sourceRenderEventCount: renderEvidence.events.count,
            anchorEventCount: statistics.anchorEventCount,
            activeOffsetCount: statistics.activeOffsetCount,
            protectedRoleActiveOffsetCount:
                statistics.protectedRoleActiveOffsetCount,
            anchorActiveOffsetCount: statistics.anchorActiveOffsetCount,
            minimumOffsetInSteps: statistics.minimumOffset,
            maximumOffsetInSteps: statistics.maximumOffset,
            maximumRoleSpreadInSteps:
                statistics.maximumOffset - statistics.minimumOffset,
            anchorMinimumOffsetInSteps: statistics.anchorMinimumOffset,
            anchorMaximumOffsetInSteps: statistics.anchorMaximumOffset,
            anchorOffsetPatternFingerprint:
                statistics.anchorFingerprint,
            shadowMinimumOffsetInSteps: statistics.shadowMinimumOffset,
            shadowMaximumOffsetInSteps: statistics.shadowMaximumOffset,
            responseMinimumOffsetInSteps: statistics.responseMinimumOffset,
            responseMaximumOffsetInSteps: statistics.responseMaximumOffset,
            scoreFingerprint: scoreFingerprint,
            renderFingerprint: renderFingerprint,
            appliedGateFingerprint: appliedGateFingerprint,
            anchorSignal: anchorSignal,
            shadowSignal: shadowSignal,
            responseSignal: responseSignal,
            bindingValid: bindingValid,
            finite: finite
        )
    }

    @inline(never)
    private static func upperTimingScheduleEnabled(_ block: RenderBlock) -> Bool {
        guard block.resolvedPerformance.performance.signatureEvent !=
                .textureCollapse else {
            return false
        }
        for role in block.resolvedPerformance.performance.roles {
            if role == .motif || role == .response || role == .atmosphere ||
                role == .transition {
                return true
            }
        }
        return false
    }

    @inline(never)
    private static func upperTimingStatistics(
        scoreNotes: [ResolvedUpperNote],
        renderEvents: [UpperTimingRenderEvent]
    ) -> UpperTimingStatistics {
        var offsets: [Double] = []
        offsets.reserveCapacity(scoreNotes.count)
        var activeOffsetCount = 0
        for note in scoreNotes {
            offsets.append(note.timingOffsetInSteps)
            if note.timingOffsetInSteps.bitPattern != 0 {
                activeOffsetCount += 1
            }
        }

        var anchorOffsets: [Double] = []
        var shadowOffsets: [Double] = []
        var responseOffsets: [Double] = []
        var protectedRoleActiveOffsetCount = 0
        var anchorActiveOffsetCount = 0
        var anchorEventCount = 0
        for event in renderEvents {
            switch event.role {
            case .anchor:
                anchorEventCount += 1
                anchorOffsets.append(event.requestedOffsetInSteps)
                if event.requestedOffsetInSteps.bitPattern != 0 {
                    anchorActiveOffsetCount += 1
                }
            case .shadow:
                shadowOffsets.append(event.requestedOffsetInSteps)
            case .response:
                responseOffsets.append(event.requestedOffsetInSteps)
            case .atmosphere, .transition:
                if event.requestedOffsetInSteps.bitPattern != 0 {
                    protectedRoleActiveOffsetCount += 1
                }
            }
        }
        return UpperTimingStatistics(
            activeOffsetCount: activeOffsetCount,
            protectedRoleActiveOffsetCount: protectedRoleActiveOffsetCount,
            anchorActiveOffsetCount: anchorActiveOffsetCount,
            anchorEventCount: anchorEventCount,
            minimumOffset: offsets.min() ?? 0,
            maximumOffset: offsets.max() ?? 0,
            anchorMinimumOffset: anchorOffsets.min() ?? 0,
            anchorMaximumOffset: anchorOffsets.max() ?? 0,
            anchorFingerprint:
                AutonomousUpperTimingBarEvidence.offsetPatternFingerprint(
                    anchorOffsets
                ),
            shadowMinimumOffset: shadowOffsets.min() ?? 0,
            shadowMaximumOffset: shadowOffsets.max() ?? 0,
            responseMinimumOffset: responseOffsets.min() ?? 0,
            responseMaximumOffset: responseOffsets.max() ?? 0
        )
    }

    @inline(never)
    private static func upperTimingBindingIsValid(
        block: RenderBlock,
        renderEvidence: UpperTimingRenderEvidence,
        planBPM: Double,
        routeSampleRate: Double,
        sourceScoreNoteCount: Int,
        scoreTupleCount: Int,
        renderTupleCount: Int,
        scoreFingerprint: String,
        renderFingerprint: String,
        eventGateFacts: [UpperTimingAppliedGateFact],
        actualGateFacts: [UpperTimingAppliedGateFact],
        anchorSignalCount: Int,
        shadowSignalCount: Int,
        responseSignalCount: Int
    ) -> Bool {
        guard renderEvidence.bar == block.bar,
              renderEvidence.chapter ==
                block.resolvedPerformance.interlockChapter,
              renderEvidence.relation ==
                block.synthPerformance.upperTimingRelation,
              renderEvidence.performanceCharacter ==
                block.resolvedPerformance.performanceCharacter,
              renderEvidence.bpm == planBPM,
              renderEvidence.sampleRate == routeSampleRate,
              renderEvidence.renderedFrameCount == block.left.count,
              renderEvidence.renderedFrameCount == block.right.count,
              sourceScoreNoteCount <= maximumUpperTimingEventsPerBar,
              renderEvidence.events.count <= maximumUpperTimingEventsPerBar,
              block.upperNoteRenderEvidence.count <=
                maximumUpperTimingEventsPerBar,
              sourceScoreNoteCount == renderEvidence.events.count,
              renderEvidence.events.count ==
                block.upperNoteRenderEvidence.count,
              scoreTupleCount == renderTupleCount,
              scoreFingerprint == renderFingerprint,
              eventGateFacts == actualGateFacts else {
            return false
        }
        for fact in actualGateFacts {
            guard fact.onsetFrame >= 0,
                  fact.requestedGateEndFrame > fact.onsetFrame,
                  fact.appliedGateEndFrame >= fact.onsetFrame,
                  fact.appliedGateEndFrame <= min(
                    fact.requestedGateEndFrame,
                    renderEvidence.renderedFrameCount
                  ) else {
                return false
            }
        }
        var anchorCount = 0
        var shadowCount = 0
        var responseCount = 0
        for event in renderEvidence.events {
            switch event.role {
            case .anchor: anchorCount += 1
            case .shadow: shadowCount += 1
            case .response: responseCount += 1
            case .atmosphere, .transition: break
            }
        }
        return anchorSignalCount == anchorCount &&
            shadowSignalCount == shadowCount &&
            responseSignalCount == responseCount
    }

    @inline(never)
    private static func upperTimingIsFinite(
        planBPM: Double,
        routeSampleRate: Double,
        scoreNotes: [ResolvedUpperNote],
        renderEvents: [UpperTimingRenderEvent],
        signals: [AutonomousUpperTimingRoleSignalEvidence]
    ) -> Bool {
        guard planBPM.isFinite, routeSampleRate.isFinite else { return false }
        for note in scoreNotes where !note.timingOffsetInSteps.isFinite {
            return false
        }
        for event in renderEvents
        where !event.requestedOffsetInSteps.isFinite {
            return false
        }
        for signal in signals where !signal.isFinite { return false }
        return true
    }

    @inline(never)
    private static func scoreUpperTimingTuples(
        _ notes: [ResolvedUpperNote],
        stepFrames: Double,
        frameCount: Int
    ) -> [UpperTimingFingerprintTuple] {
        var result: [UpperTimingFingerprintTuple] = []
        result.reserveCapacity(notes.count)
        for note in notes {
            let expectedOnsetFrame = VoiceRenderer.upperNoteStartFrame(
                note: note,
                stepFrames: stepFrames,
                frameCount: frameCount
            )
            let durationFrames = VoiceRenderer.upperNoteDurationFrames(
                note: note,
                stepFrames: stepFrames
            )
            let requestedEnd = expectedOnsetFrame.addingReportingOverflow(
                durationFrames
            )
            result.append(UpperTimingFingerprintTuple(
                role: note.role.rawValue,
                baseOnsetStep: note.onsetStep,
                offsetBitPattern: note.timingOffsetInSteps.bitPattern,
                expectedOnsetFrame: expectedOnsetFrame,
                appliedOnsetFrame: expectedOnsetFrame,
                requestedGateEndFrame: requestedEnd.overflow
                    ? Int.max : requestedEnd.partialValue
            ))
        }
        return sortedUpperTimingTuples(result)
    }

    @inline(never)
    private static func renderUpperTimingTuples(
        _ events: [UpperTimingRenderEvent]
    ) -> [UpperTimingFingerprintTuple] {
        var result: [UpperTimingFingerprintTuple] = []
        result.reserveCapacity(events.count)
        for event in events {
            result.append(UpperTimingFingerprintTuple(
                role: event.role.rawValue,
                baseOnsetStep: event.baseOnsetStep,
                offsetBitPattern: event.requestedOffsetInSteps.bitPattern,
                expectedOnsetFrame: event.expectedOnsetFrame,
                appliedOnsetFrame: event.appliedOnsetFrame,
                requestedGateEndFrame: event.requestedGateEndFrame
            ))
        }
        return sortedUpperTimingTuples(result)
    }

    @inline(never)
    private static func upperTimingGateFacts(
        _ events: [UpperTimingRenderEvent]
    ) -> [UpperTimingAppliedGateFact] {
        var result: [UpperTimingAppliedGateFact] = []
        result.reserveCapacity(events.count)
        for event in events {
            result.append(UpperTimingAppliedGateFact(
                role: event.role,
                onsetFrame: event.appliedOnsetFrame,
                requestedGateEndFrame: event.requestedGateEndFrame,
                appliedGateEndFrame: event.appliedGateEndFrame
            ))
        }
        return result.sorted(by: upperTimingGateFactOrder)
    }

    @inline(never)
    private static func upperNoteGateFacts(
        _ evidence: [UpperNoteRenderEvidence]
    ) -> [UpperTimingAppliedGateFact] {
        var result: [UpperTimingAppliedGateFact] = []
        result.reserveCapacity(evidence.count)
        for item in evidence {
            result.append(UpperTimingAppliedGateFact(
                role: item.role,
                onsetFrame: item.onsetFrame,
                requestedGateEndFrame: item.requestedGateEndFrame,
                appliedGateEndFrame: item.appliedGateEndFrame
            ))
        }
        return result.sorted(by: upperTimingGateFactOrder)
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

    package static func validatedLiveMasterEvidence(
        inputs: [AutonomousLiveMasterRenderValidationInput],
        outgoingState: LiveMasterHeadroomContinuationState,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> AutonomousValidatedLiveMasterEvidence? {
        guard !inputs.isEmpty, inputs.count <= Self.maximumBarCount,
              !cancellationRequested() else { return nil }
        var preTrimFingerprints: [String] = []
        var postTrimFingerprints: [String] = []
        preTrimFingerprints.reserveCapacity(inputs.count)
        postTrimFingerprints.reserveCapacity(inputs.count)
        var requestedTrim: Double?
        var appliedTrim: Double?
        var appliedGain: Double?
        for input in inputs {
            guard !cancellationRequested(), !input.left.isEmpty,
                  input.left.count == input.right.count else { return nil }
            let evidence = input.evidence
            let actualPostHash = ExactPCMFingerprint.stereo(
                left: input.left,
                right: input.right
            )
            let actualPostNonzeroCount = input.left.reduce(0) {
                $0 + ($1 == 0 ? 0 : 1)
            } + input.right.reduce(0) {
                $0 + ($1 == 0 ? 0 : 1)
            }
            let totalSampleCount = input.left.count.addingReportingOverflow(
                input.right.count
            )
            guard evidence.requestedTrimDB.isFinite,
                  evidence.appliedTrimDB.isFinite,
                  evidence.appliedGain.isFinite,
                  (-3...0).contains(evidence.requestedTrimDB),
                  (-3...0).contains(evidence.appliedTrimDB),
                  evidence.requestedTrimDB ==
                    outgoingState.committedTrimDB,
                  evidence.appliedTrimDB == outgoingState.committedTrimDB,
                  evidence.appliedGain ==
                    pow(10, evidence.appliedTrimDB / 20),
                  Self.isLiveFingerprint(
                    evidence.preTrimStereoSampleHash
                  ),
                  evidence.postTrimStereoSampleHash == actualPostHash,
                  evidence.preTrimNonzeroSampleCount >= 0,
                  !totalSampleCount.overflow,
                  evidence.preTrimNonzeroSampleCount <=
                    totalSampleCount.partialValue,
                  evidence.postTrimNonzeroSampleCount ==
                    actualPostNonzeroCount,
                  evidence.exactScaleMatches else { return nil }
            if let requestedTrim,
               requestedTrim != evidence.requestedTrimDB { return nil }
            if let appliedTrim,
               appliedTrim != evidence.appliedTrimDB { return nil }
            if let appliedGain,
               appliedGain != evidence.appliedGain { return nil }
            requestedTrim = evidence.requestedTrimDB
            appliedTrim = evidence.appliedTrimDB
            appliedGain = evidence.appliedGain
            preTrimFingerprints.append(evidence.preTrimStereoSampleHash)
            postTrimFingerprints.append(actualPostHash)
        }
        guard let requestedTrim, let appliedTrim, let appliedGain,
              !cancellationRequested() else { return nil }
        return AutonomousValidatedLiveMasterEvidence(
            requestedTrimDB: requestedTrim,
            appliedTrimDB: appliedTrim,
            appliedGain: appliedGain,
            preTrimPCMFingerprint: liveMasterPhrasePCMFingerprint(
                preTrimFingerprints
            ),
            postTrimPCMFingerprint: liveMasterPhrasePCMFingerprint(
                postTrimFingerprints
            ),
            validatedBlockCount: inputs.count
        )
    }

    package static func liveMasterPhrasePCMFingerprint(
        _ orderedBlockFingerprints: [String]
    ) -> String {
        var sink = StreamingFNV1a()
        sink.domain("live-master-phrase-pcm.typed.v1")
        sink.collection(orderedBlockFingerprints.count)
        for fingerprint in orderedBlockFingerprints {
            sink.string(fingerprint)
        }
        return fixedWidthFingerprintHex(sink.value)
    }

    package var isFinite: Bool {
        symbolic.isFinite && fullMix.isFinite && crossPhraseTransition.finite &&
            masking.allSatisfy { $0.isFinite } &&
            stems.allSatisfy { $0.isFinite } &&
            automaticMix.allSatisfy { $0.isFinite } &&
            kickSyntax.allSatisfy { $0.isFinite } &&
            foundationRhythm.allSatisfy { $0.isFinite } &&
            groovePulse.allSatisfy { $0.isFinite } &&
            closedHat.allSatisfy { $0.isFinite } &&
            upperPercussionTail.allSatisfy { $0.isFinite } &&
            modalPercussion.allSatisfy { $0.isFinite } &&
            instruments.allSatisfy { $0.isFinite } &&
            percussionEchoTexture.allSatisfy { $0.isFinite } &&
            phraseComposition.allSatisfy { $0.finite } &&
            pulseEchoDrive.allSatisfy { $0.isFinite } &&
            spatialFDN.allSatisfy { $0.isFinite } &&
            upperTiming.allSatisfy { $0.isFinite } &&
            incomingLiveMasterTrimDB.isFinite &&
            requestedLiveMasterTrimDB.isFinite &&
            appliedLiveMasterTrimDB.isFinite && liveMasterGain.isFinite &&
            routeContinuation.isFinite &&
            preGraphUpperTimbreEvidence.candidateValuesAreFinite &&
            postGraphUpperTimbreEvidence.candidateValuesAreFinite
    }

    package var isComplete: Bool {
        completenessFailures.isEmpty
    }

    /// Deterministic, bounded diagnostics for an otherwise opaque completeness
    /// rejection. These codes carry no PCM, hashes, events, or metric values.
    package var completenessFailures: [AutonomousCandidateCompletenessFailure] {
        let expectedBars = Set(fullMix.bars.map { $0.bar })
        var failures: [AutonomousCandidateCompletenessFailure] = []
        if !identityAndPrimaryEvidenceAreComplete() {
            failures.append(.identityAndPrimaryEvidence)
        }
        if !crossPhraseTransition.isComplete {
            failures.append(.crossPhraseTransitionEvidence)
        }
        if !symbolicBarCoverageIsComplete() {
            failures.append(.symbolicBarCoverage)
        }
        if !automaticMixControllerTrajectoryIsComplete() {
            failures.append(.automaticMixControllerTrajectory)
        }
        if !sourceCountsAreComplete() { failures.append(.sourceCounts) }
        if !maskingEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.maskingEvidence)
        }
        if !stemEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.stemEvidence)
        }
        if !automaticMixEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.automaticMixEvidence)
        }
        if !kickSyntaxEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.kickSyntaxEvidence)
        }
        if !foundationRhythmEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.foundationRhythmEvidence)
        }
        if !climaxArcEvidenceIsComplete() {
            failures.append(.climaxArcEvidence)
        }
        if !groovePulseEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.groovePulseEvidence)
        }
        if !closedHatEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.closedHatEvidence)
        }
        if !upperPercussionTailEvidenceIsComplete(
            expectedBars: expectedBars
        ) {
            failures.append(.upperPercussionTailEvidence)
        }
        if !modalPercussionEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.modalPercussionEvidence)
        }
        if !instrumentEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.instrumentEvidence)
        }
        if !percussionEchoTextureEvidenceIsComplete(
            expectedBars: expectedBars
        ) {
            failures.append(.percussionEchoTextureEvidence)
        }
        if !phraseCompositionEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.phraseCompositionEvidence)
        }
        if !pulseEchoDriveEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.pulseEchoDriveEvidence)
        }
        if !spatialFDNEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.spatialFDNEvidence)
        }
        if !upperTimingEvidenceIsComplete(expectedBars: expectedBars) {
            failures.append(.upperTimingEvidence)
        }
        if !liveMasterEvidenceIsComplete() {
            failures.append(.liveMasterEvidence)
        }
        return failures
    }

    @inline(never)
    private func identityAndPrimaryEvidenceAreComplete() -> Bool {
        guard schemaVersion == Self.schemaVersion,
              !planFingerprint.isEmpty, !graphFingerprint.isEmpty,
              planFingerprint == symbolic.planFingerprint,
              graphFingerprint == graph.graphFingerprint,
              symbolic.isComplete, hardGates.isComplete, fullMix.isComplete,
              crossPhraseTransition.isComplete,
              graph.isComplete, routeContinuation.isComplete,
              sourceInstrumentBarCount == instruments.count,
              instruments.count == fullMix.sourceBarCount,
              sourceFoundationRhythmBarCount == foundationRhythm.count,
              foundationRhythm.count == fullMix.sourceBarCount,
              sourceModalPercussionBarCount == modalPercussion.count,
              modalPercussion.count == fullMix.sourceBarCount,
              sourcePercussionEchoTextureBarCount ==
                percussionEchoTexture.count,
              percussionEchoTexture.count == fullMix.sourceBarCount,
              sourcePhraseCompositionBarCount == phraseComposition.count,
              phraseComposition.count == fullMix.sourceBarCount,
              sourcePulseEchoDriveBarCount == pulseEchoDrive.count,
              pulseEchoDrive.count == fullMix.sourceBarCount,
              sourceSpatialFDNBarCount == spatialFDN.count,
              spatialFDN.count == fullMix.sourceBarCount,
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
                AutonomousCandidateFingerprint.combinedController(
                    kickCorrectionDB: finalKick.gainDB,
                    liveMasterStateFingerprint:
                        outgoingLiveMasterStateFingerprint,
                    proposalFingerprint: nil
                ) else {
            return false
        }
        return true
    }

    @inline(never)
    private func liveMasterEvidenceIsComplete() -> Bool {
        let fingerprints = [
            incomingLiveMasterStateFingerprint,
            outgoingLiveMasterStateFingerprint,
            preLiveMasterPCMFingerprint,
            postLiveMasterPCMFingerprint,
        ]
        guard incomingLiveMasterRevision >= 0,
              outgoingLiveMasterRevision >= 0,
              incomingLiveMasterTrimDB.isFinite,
              (-3...0).contains(incomingLiveMasterTrimDB),
              (0...2).contains(incomingLiveMasterCleanWindowCount),
              (0...2).contains(outgoingLiveMasterCleanWindowCount),
              fingerprints.allSatisfy(Self.isLiveFingerprint),
              liveObservationFingerprint.map(Self.isLiveFingerprint) ?? true,
              liveProposalFingerprint.map(Self.isLiveFingerprint) ?? true,
              requestedLiveMasterTrimDB.isFinite,
              appliedLiveMasterTrimDB.isFinite,
              liveMasterGain.isFinite,
              (-3...0).contains(requestedLiveMasterTrimDB),
              (-3...0).contains(appliedLiveMasterTrimDB),
              liveMasterGain > 0, liveMasterGain <= 1,
              liveMasterGain == pow(10, appliedLiveMasterTrimDB / 20),
              liveMasterScalingMatches,
              liveProposalBindingMatches,
              liveEarliestEligibleFutureSample.map({ $0 > 0 }) ?? true,
              liveAppliedFutureSample.map({ $0 > 0 }) ?? true else {
            return false
        }
        let hasProposal = liveProposalFingerprint != nil
        if !hasProposal {
            return liveProposalOutcome == .hold &&
                liveObservationFingerprint == nil &&
                liveEarliestEligibleFutureSample == nil &&
                outgoingLiveMasterRevision == incomingLiveMasterRevision &&
                outgoingLiveMasterStateFingerprint ==
                    incomingLiveMasterStateFingerprint &&
                outgoingLiveMasterCleanWindowCount ==
                    incomingLiveMasterCleanWindowCount &&
                incomingLiveMasterTrimDB == appliedLiveMasterTrimDB &&
                requestedLiveMasterTrimDB == appliedLiveMasterTrimDB &&
                liveAppliedFutureSample == nil &&
                (liveMasterGain != 1 ||
                    preLiveMasterPCMFingerprint ==
                        postLiveMasterPCMFingerprint)
        }
        let liveBoundaryValid: Bool
        if let earliest = liveEarliestEligibleFutureSample,
           let applied = liveAppliedFutureSample {
            liveBoundaryValid = applied >= earliest
        } else {
            liveBoundaryValid = false
        }
        if liveProposalOutcome == .unavailable {
            return outgoingLiveMasterRevision == incomingLiveMasterRevision &&
                outgoingLiveMasterStateFingerprint ==
                    incomingLiveMasterStateFingerprint &&
                outgoingLiveMasterCleanWindowCount ==
                    incomingLiveMasterCleanWindowCount &&
                incomingLiveMasterTrimDB == appliedLiveMasterTrimDB &&
                liveBoundaryValid &&
                requestedLiveMasterTrimDB == appliedLiveMasterTrimDB
        }
        let trimDelta = appliedLiveMasterTrimDB - incomingLiveMasterTrimDB
        let transitionValid: Bool
        switch liveProposalOutcome {
        case .unavailable:
            transitionValid = false
        case .hold:
            transitionValid = trimDelta == 0
        case .attenuate:
            transitionValid = trimDelta < 0 &&
                trimDelta >= -LiveMasterHeadroomController.attackStepDB &&
                outgoingLiveMasterCleanWindowCount == 0
        case .recover:
            transitionValid = trimDelta > 0 &&
                trimDelta <= LiveMasterHeadroomController.recoveryStepDB &&
                incomingLiveMasterCleanWindowCount >=
                    LiveMasterHeadroomController.cleanWindowsForRecovery - 1 &&
                outgoingLiveMasterCleanWindowCount == 0
        }
        return liveObservationFingerprint != nil &&
            incomingLiveMasterRevision < Int.max &&
            outgoingLiveMasterRevision == incomingLiveMasterRevision + 1 &&
            outgoingLiveMasterStateFingerprint !=
                incomingLiveMasterStateFingerprint &&
            requestedLiveMasterTrimDB == appliedLiveMasterTrimDB &&
            liveBoundaryValid &&
            transitionValid
    }

    private static func isLiveFingerprint(_ value: String) -> Bool {
        value.utf8.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
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
           let target = mix.targetKickOverFoundationDB,
           let sourceKickRMS = mix.sourceKickRMS,
           let sourceKickActiveRMS = mix.sourceKickActiveRMS {
            guard controllerShouldMeasure,
                  target == expectedKickTarget(for: companion),
                  sourceKickRMS > 0,
                  sourceKickActiveRMS > 0 else {
                return false
            }
            let expectedMeasured =
                20 * log10(max(sourceKickActiveRMS, 0.000_000_001)) -
                20 * log10(max(foundation.activeRMS, 0.000_000_001))
            let expectedPostRMS = sourceKickRMS * pow(10, actualKick / 20)
            let postRMSTolerance = max(1e-12, expectedPostRMS * 1e-6)
            guard abs(measured - expectedMeasured) <= 1e-12,
                  abs(kick.rms - expectedPostRMS) <= postRMSTolerance else {
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
            sourceFoundationRhythmBarCount == foundationRhythm.count &&
            sourceGroovePulseBarCount == groovePulse.count &&
            sourceClosedHatBarCount == closedHat.count &&
            sourceUpperPercussionTailBarCount == upperPercussionTail.count &&
            sourceModalPercussionBarCount == modalPercussion.count &&
            sourceInstrumentBarCount == instruments.count &&
            sourcePercussionEchoTextureBarCount ==
                percussionEchoTexture.count &&
            sourcePhraseCompositionBarCount == phraseComposition.count &&
            sourcePulseEchoDriveBarCount == pulseEchoDrive.count &&
            sourceSpatialFDNBarCount == spatialFDN.count &&
            sourceUpperTimingBarCount == upperTiming.count &&
            masking.count == fullMix.sourceBarCount &&
            stems.count == fullMix.sourceBarCount &&
            automaticMix.count == fullMix.sourceBarCount &&
            kickSyntax.count == fullMix.sourceBarCount &&
            foundationRhythm.count == fullMix.sourceBarCount &&
            groovePulse.count == fullMix.sourceBarCount &&
            closedHat.count == fullMix.sourceBarCount &&
            upperPercussionTail.count == fullMix.sourceBarCount &&
            modalPercussion.count == fullMix.sourceBarCount &&
            instruments.count == fullMix.sourceBarCount &&
            percussionEchoTexture.count == fullMix.sourceBarCount &&
            phraseComposition.count == fullMix.sourceBarCount &&
            pulseEchoDrive.count == fullMix.sourceBarCount &&
            spatialFDN.count == fullMix.sourceBarCount &&
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
                let isTerminalHang = climaxArc.hang.active &&
                    climaxArc.hang.bar == syntax.bar
                let expectedWeakPulseSteps = isTerminalHang
                    ? ClimaxHangContract.preHangWeakPulseSteps
                    : KickSyntaxResolver.canonicalWeakPulseSteps
                let weakPulsesAreAudible =
                    pulse.sourceScoreEventCount ==
                        expectedWeakPulseSteps.count &&
                    pulse.sourceRenderEventCount == pulse.sourceScoreEventCount &&
                    pulse.events.map(\.step) == expectedWeakPulseSteps &&
                    pulse.events.allSatisfy {
                        $0.intensity > 0 && $0.sourceRMS > 0 && $0.finite
                    }
                let motifAssignmentIsPresent = instrument.architectures.contains {
                    $0.assignments.contains { $0.use == InstrumentUse.motif.rawValue }
                }
                guard stemIsSilent, weakPulsesAreAudible,
                      isTerminalHang || motifAssignmentIsPresent else {
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
        guard phraseKind == .energyRelease,
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

    @inline(never)
    private func foundationRhythmEvidenceIsComplete(
        expectedBars: Set<Int>
    ) -> Bool {
        guard let phraseKind = AutonomousPhraseKind(rawValue: symbolic.phraseKind),
              Set(foundationRhythm.map { $0.bar }) == expectedBars,
              foundationRhythm.map({ $0.bar }) == fullMix.bars.map({ $0.bar }),
              foundationRhythm.count == fullMix.sourceBarCount else {
            return false
        }
        for index in foundationRhythm.indices {
            let rhythm = foundationRhythm[index]
            let stem = stems[index]
            let mix = automaticMix[index]
            let instrument = instruments[index]
            guard rhythm.bar == stem.bar,
                  rhythm.bar == mix.bar,
                  rhythm.bar == instrument.bar,
                  rhythm.isComplete(
                    sampleRate: routeContinuation.sampleRate
                  ),
                  let foundationStem = stem.roles.first(where: {
                    $0.role == MixRole.foundation.rawValue
                  }) else {
                return false
            }
            guard FoundationRhythmicRelation(rawValue: rhythm.relation) ==
                    .dottedThreeSixteenth else {
                continue
            }
            let assignmentIsPresent = instrument.architectures.contains {
                architecture in
                architecture.assignments.contains {
                    $0.use == InstrumentUse.foundationBass.rawValue &&
                        $0.patch == InstrumentPatch.bassPluck.rawValue
                }
            }
            guard phraseKind == .lock,
                  mix.foundationCompanion == FoundationCompanion.bass.rawValue,
                  assignmentIsPresent,
                  foundationStem.peak > 0,
                  foundationStem.rms > 0,
                  foundationStem.activeRMS > 0,
                  foundationStem.occupancy > 0 else {
                return false
            }
        }
        return foundationRhythmArcIsCanonical()
    }

    @inline(never)
    private func foundationRhythmArcIsCanonical() -> Bool {
        var index = 0
        while index < foundationRhythm.count {
            let current = foundationRhythm[index]
            guard let relation = FoundationRhythmicRelation(
                rawValue: current.relation
            ) else { return false }
            if relation == .established {
                index += 1
                continue
            }
            guard current.pairPhase == 0,
                  foundationRhythm.indices.contains(index + 1) else {
                return false
            }
            let next = foundationRhythm[index + 1]
            guard next.relation ==
                    FoundationRhythmicRelation.dottedThreeSixteenth.rawValue,
                  next.pairPhase == 1,
                  current.bar < Int.max,
                  next.bar == current.bar + 1,
                  Self.macroPosition(current.bar).isMultiple(of: 4) else {
                return false
            }
            index += 2
        }
        return true
    }

    @inline(never)
    private func climaxArcEvidenceIsComplete() -> Bool {
        climaxArc.isComplete(
            phraseKind: symbolic.phraseKind,
            startBar: symbolic.startBar,
            declaredBarCount: symbolic.declaredBarCount,
            kickSyntax: kickSyntax,
            sampleRate: routeContinuation.sampleRate
        )
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
    private func upperPercussionTailEvidenceIsComplete(
        expectedBars: Set<Int>
    ) -> Bool {
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: symbolic.phraseKind
        ) else {
            return false
        }
        return Set(upperPercussionTail.map(\.bar)) == expectedBars &&
            upperPercussionTail.map(\.bar) == fullMix.bars.map(\.bar) &&
            upperPercussionTail.allSatisfy {
                $0.isComplete(
                    sampleRate: routeContinuation.sampleRate,
                    phraseKind: phraseKind
                )
            } && upperPercussionTail.count == fullMix.sourceBarCount
    }

    @inline(never)
    private func modalPercussionEvidenceIsComplete(
        expectedBars: Set<Int>
    ) -> Bool {
        guard Set(modalPercussion.map(\.bar)) == expectedBars,
              modalPercussion.map(\.bar) == fullMix.bars.map(\.bar),
              modalPercussion.count == fullMix.sourceBarCount,
              modalPercussion.allSatisfy({
                  $0.isComplete(sampleRate: routeContinuation.sampleRate)
              }) else {
            return false
        }
        for index in modalPercussion.indices {
            let bar = modalPercussion[index]
            if index > 0,
               bar.incomingStateFingerprint !=
                modalPercussion[index - 1].outgoingStateFingerprint {
                return false
            }
            if !bar.events.allSatisfy({
                $0.outgoingVoiceStateFingerprint ==
                    bar.outgoingStateFingerprint
            }) {
                return false
            }
        }
        return true
    }

    @inline(never)
    private func instrumentEvidenceIsComplete(expectedBars: Set<Int>) -> Bool {
        Set(instruments.map { $0.bar }) == expectedBars &&
            instruments.allSatisfy {
                $0.isComplete(sampleRate: routeContinuation.sampleRate)
            } &&
            instruments.count == fullMix.sourceBarCount
    }

    @inline(never)
    private func percussionEchoTextureEvidenceIsComplete(
        expectedBars: Set<Int>
    ) -> Bool {
        guard let phraseKind = AutonomousPhraseKind(
            rawValue: symbolic.phraseKind
        ), Set(percussionEchoTexture.map { $0.bar }) == expectedBars,
           percussionEchoTexture.map({ $0.bar }) ==
            fullMix.bars.map({ $0.bar }),
           percussionEchoTexture.count == fullMix.sourceBarCount else {
            return false
        }
        return zip(percussionEchoTexture, kickSyntax).allSatisfy { texture, kick in
            texture.bar == kick.bar && texture.kickSyntaxRole == kick.role &&
                texture.isComplete(
                    sampleRate: routeContinuation.sampleRate,
                    phraseKind: phraseKind
                )
        }
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
                instruments: instrument
            ) else {
                return false
            }
        }
        return true
    }

    @inline(never)
    private func phraseCompositionEvidenceIsComplete(
        expectedBars: Set<Int>
    ) -> Bool {
        guard Set(phraseComposition.map { $0.bar }) == expectedBars,
              phraseComposition.map(\.bar) == fullMix.bars.map(\.bar),
              phraseComposition.count == fullMix.sourceBarCount else {
            return false
        }
        let phraseLength = phraseComposition.count
        return phraseComposition.enumerated().allSatisfy { index, evidence in
            evidence.isComplete(
                phraseKind: symbolic.phraseKind,
                expectedLocalBar: index,
                expectedPhraseLength: phraseLength,
                expectedSampleRate: routeContinuation.sampleRate
            )
        }
    }

    @inline(never)
    private func spatialFDNEvidenceIsComplete(
        expectedBars: Set<Int>
    ) -> Bool {
        Set(spatialFDN.map { $0.bar }) == expectedBars &&
            spatialFDN.map(\.bar) == fullMix.bars.map(\.bar) &&
            spatialFDN.count == fullMix.sourceBarCount &&
            spatialFDN.allSatisfy {
                $0.isComplete(
                    routeSampleRate: routeContinuation.sampleRate
                )
            }
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
                      phraseKind: phraseKind
                  ) else {
                return false
            }
        }
        return true
    }

    package var playbackGateEvidence: AutonomousPlaybackGateEvidence {
        AutonomousPlaybackGateEvidence(
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

    /// True only when the candidate record is complete and finite and every
    /// graph, signal, route, timbre, buffer, and provenance hard gate passes,
    /// leaving symbolic phrase interest as the sole rejection. This evidence
    /// may request a different serial plan; it never makes this PCM playable.
    package var symbolicInterestIsOnlyHardGateFailure: Bool {
        isComplete && isFinite &&
            !symbolic.interestValid && !hardGates.symbolicValid &&
            hardGates.graphValid && hardGates.audioSafetyValid &&
            hardGates.fullMixFinite && hardGates.upperTimbreFinite &&
            hardGates.blocksPresent && hardGates.blockChannelsAligned &&
            hardGates.allSamplesFinite && hardGates.completeInputs &&
            graph.validationValid && fullMix.signalSafetyValid &&
            liveProposalOutcome != .unavailable &&
            postGraphUpperTimbreEvidence.finite &&
            postGraphUpperTimbreEvidence.candidateValuesAreFinite
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
            crossPhraseTransition.hardGateValid &&
            liveProposalOutcome != .unavailable &&
            postGraphUpperTimbreEvidence.finite &&
            postGraphUpperTimbreEvidence.candidateValuesAreFinite
    }

    /// The core signal/structure subset. Passing this alone never authorizes a
    /// commit; the primary evaluator also requires the complete vector and its
    /// installed-profile verdict.
    package var playbackHardGatesPassed: Bool {
        hardGates.passed && hardGateEvidenceIsConsistent
    }

    private var hardGateEvidenceIsConsistent: Bool {
        symbolic.interestValid && graph.validationValid &&
            fullMix.signalSafetyValid &&
            crossPhraseTransition.hardGateValid &&
            postGraphUpperTimbreEvidence.finite &&
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
            climaxArc.recordIsStructurallyValid &&
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
            sourceFoundationRhythmBarCount >= foundationRhythm.count &&
            sourceFoundationRhythmBarCount <= Self.maximumBarCount &&
            sourceGroovePulseBarCount >= groovePulse.count &&
            sourceClosedHatBarCount >= closedHat.count &&
            sourceUpperPercussionTailBarCount >= upperPercussionTail.count &&
            sourceUpperPercussionTailBarCount <= Self.maximumBarCount &&
            sourceModalPercussionBarCount >= modalPercussion.count &&
            sourceModalPercussionBarCount <= Self.maximumBarCount &&
            sourceInstrumentBarCount >= instruments.count &&
            sourcePercussionEchoTextureBarCount >=
                percussionEchoTexture.count &&
            sourcePercussionEchoTextureBarCount <= Self.maximumBarCount &&
            sourcePulseEchoDriveBarCount >= pulseEchoDrive.count &&
            sourceSpatialFDNBarCount >= spatialFDN.count &&
            sourceSpatialFDNBarCount <= Self.maximumBarCount &&
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
            foundationRhythm.count <= Self.maximumBarCount &&
            groovePulse.count <= Self.maximumBarCount &&
            closedHat.count <= Self.maximumBarCount &&
            upperPercussionTail.count <= Self.maximumBarCount &&
            modalPercussion.count <= Self.maximumBarCount &&
            instruments.count <= Self.maximumBarCount &&
            percussionEchoTexture.count <= Self.maximumBarCount &&
            phraseComposition.count <= Self.maximumBarCount &&
            pulseEchoDrive.count <= Self.maximumBarCount &&
            spatialFDN.count <= Self.maximumBarCount &&
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
            foundationRhythmRecordsAreBounded() &&
            groovePulseRecordsAreBounded() &&
            closedHatRecordsAreBounded() &&
            upperPercussionTailRecordsAreBounded() &&
            modalPercussionRecordsAreBounded() &&
            instrumentRecordsAreBounded() &&
            percussionEchoTextureRecordsAreBounded() &&
            pulseEchoDriveRecordsAreBounded() &&
            spatialFDNRecordsAreBounded() && upperTimingRecordsAreBounded()
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
                $0.audibleNonzeroSampleCount <= $0.renderedFrameCount &&
                (0...KickSourceDynamicsContract.maximumEventsPerBar)
                    .contains($0.sourceDynamics.renderedEventCount) &&
                (0...KickSourceDynamicsContract.maximumProcessedSampleCount(
                    sampleRate: QualityQualificationContract
                        .maximumSupportedSampleRate
                )).contains($0.sourceDynamics.processedSampleCount)
        }
    }

    @inline(never)
    private func foundationRhythmRecordsAreBounded() -> Bool {
        foundationRhythm.map({ $0.bar }) == fullMix.bars.map({ $0.bar }) &&
            foundationRhythm.allSatisfy {
                (0...16).contains($0.scoreBassEventCount) &&
                    (0...16).contains($0.renderedBassEventCount) &&
                    $0.renderedFrameCount >= 0 &&
                    ($0.preKickPocket == .neutral || (
                        (0..<64).contains(
                            $0.preKickPocket.scoreEventIndex
                        ) &&
                        $0.preKickPocket.eventStartFrame >= 0 &&
                        $0.preKickPocket.naturalEndFrame >= 0 &&
                        $0.preKickPocket.naturalEndFrame <=
                            $0.renderedFrameCount &&
                        $0.preKickPocket.releaseStartFrame >= 0 &&
                        $0.preKickPocket.releaseEndFrame >= 0 &&
                        $0.preKickPocket.kickFrame >= 0 &&
                        $0.preKickPocket.kickFrame <=
                            $0.renderedFrameCount &&
                        $0.preKickPocket.releaseFrameCount >= 0 &&
                        $0.preKickPocket.releaseFrameCount <=
                            $0.renderedFrameCount &&
                        $0.preKickPocket.silenceFrameCount >= 0 &&
                        $0.preKickPocket.silenceFrameCount <=
                            $0.renderedFrameCount
                    ))
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
    private func upperPercussionTailRecordsAreBounded() -> Bool {
        upperPercussionTail.map(\.bar) == fullMix.bars.map(\.bar) &&
            upperPercussionTail.allSatisfy {
                $0.sourceScoreEventCount >= 0 &&
                    $0.sourceScoreEventCount <=
                        Self.maximumUpperPercussionTailEventsPerBar &&
                    $0.sourceRenderEventCount >= 0 &&
                    $0.sourceRenderEventCount <=
                        Self.maximumUpperPercussionTailEventsPerBar &&
                    $0.events.count <=
                        Self.maximumUpperPercussionTailEventsPerBar
            }
    }

    @inline(never)
    private func modalPercussionRecordsAreBounded() -> Bool {
        modalPercussion.map(\.bar) == fullMix.bars.map(\.bar) &&
            modalPercussion.allSatisfy {
                $0.sourceScoreEventCount >= 0 &&
                    $0.sourceScoreEventCount <=
                        Self.maximumModalPercussionEventsPerBar &&
                    $0.sourceRenderEventCount >= 0 &&
                    $0.sourceRenderEventCount <=
                        Self.maximumModalPercussionEventsPerBar &&
                    $0.events.count <=
                        Self.maximumModalPercussionEventsPerBar &&
                    (0...ModalPercussionVoice.voiceCapacity)
                        .contains($0.activeIncomingVoiceCount) &&
                    (0...ModalPercussionVoice.voiceCapacity)
                        .contains($0.activeOutgoingVoiceCount)
            }
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
    private func spatialFDNRecordsAreBounded() -> Bool {
        spatialFDN.map({ $0.bar }) == fullMix.bars.map({ $0.bar }) &&
            spatialFDN.allSatisfy {
                $0.delayFrameCounts.count <=
                    FeedbackDelayNetworkConfiguration.lineCount &&
                    $0.renderedFrameCount >= 0 &&
                    $0.activeInputFrameCount >= 0 &&
                    $0.activeInputFrameCount <= $0.renderedFrameCount &&
                    $0.activeWetFrameCount >= 0 &&
                    $0.activeWetFrameCount <= $0.renderedFrameCount &&
                    $0.firstWetFrameIndex >= -1 &&
                    $0.firstWetFrameIndex < max(1, $0.renderedFrameCount)
            }
    }

    @inline(never)
    private func percussionEchoTextureRecordsAreBounded() -> Bool {
        percussionEchoTexture.map({ $0.bar }) == fullMix.bars.map({ $0.bar }) &&
            percussionEchoTexture.allSatisfy {
                (0...8).contains($0.eligibleSourceStepMask.nonzeroBitCount) &&
                    $0.renderedFrameCount >= 0 &&
                    $0.inputWindowFrameCount >= 0 &&
                    $0.outputWindowFrameCount >= 0 &&
                    $0.delayFrameCount >= 0 &&
                    $0.transitionFrameCount >= 0 &&
                    $0.inputNonzeroSampleCount >= 0 &&
                    $0.inputNonzeroSampleCount <= $0.renderedFrameCount &&
                    $0.returnNonzeroSampleCount >= 0 &&
                    $0.returnNonzeroSampleCount <= $0.renderedFrameCount &&
                    $0.outOfWindowNonzeroSampleCount >= 0 &&
                    $0.outOfWindowNonzeroSampleCount <= $0.renderedFrameCount
            }
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
                    $0.anchorActiveOffsetCount >= 0 &&
                    $0.anchorActiveOffsetCount <=
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
            hardGates.audioSafetyValid == (
                prevalidatedSignalSafetyValid &&
                    crossPhraseTransition.hardGateValid
            ) &&
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
    package let forceHomeUpperTimbre: Bool
    package let sourceReasonCodeCount: Int
    package let reasonCodes: [QualityReasonCode]
    package let vector: AutonomousCandidateEvaluationVector

    package init(
        kind: AutonomousCandidateAttemptKind,
        forceHomeUpperTimbre: Bool = false,
        reasonCodes: [QualityReasonCode] = [],
        vector: AutonomousCandidateEvaluationVector
    ) {
        schemaVersion = Self.schemaVersion
        self.kind = kind
        self.forceHomeUpperTimbre = forceHomeUpperTimbre
        let normalizedReasons = Array(Set(reasonCodes)).sorted {
            $0.rawValue < $1.rawValue
        }
        sourceReasonCodeCount = normalizedReasons.count
        self.reasonCodes = Array(normalizedReasons.prefix(Self.maximumReasonCodeCount))
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
                    instruments: instruments
                ) && !forceHomeUpperTimbre
            )
        }
        let forceHomeTimingIsNeutral = !forceHomeUpperTimbre ||
            vector.upperTiming.allSatisfy { $0.activeOffsetCount == 0 }
        let upperTimingEligibilityMatchesAttempt = vector.upperTiming.allSatisfy {
            !$0.bindingValid || ($0.activeOffsetCount > 0) == (
                $0.normalTimingEligibility(
                    phraseKind: phraseKind
                ) && !forceHomeUpperTimbre
            )
        }
        let envelopeExpansionEligibilityMatchesAttempt =
            vector.instruments.allSatisfy { instruments in
                instruments.tonalEnvelopeExpansionActive ==
                    (instruments.tonalEnvelopeExpansionEligible &&
                        !forceHomeUpperTimbre)
            }
        let spectralRevealEligibilityMatchesAttempt =
            vector.instruments.allSatisfy { instruments in
                instruments.spectralRevealActive ==
                    (instruments.spectralRevealEligible &&
                        !forceHomeUpperTimbre)
            }
        guard schemaVersion == Self.schemaVersion,
              prevalidatedRecordIsStructurallyValid,
              vector.pulseEchoDrive.count == vector.instruments.count,
              pulseEchoEligibilityMatchesAttempt,
              forceHomeTimingIsNeutral,
              upperTimingEligibilityMatchesAttempt,
              envelopeExpansionEligibilityMatchesAttempt,
              spectralRevealEligibilityMatchesAttempt,
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
        return missingReason == !prevalidatedVectorIsComplete &&
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

package struct AutonomousCandidateEvaluationTransaction: Codable, Equatable, Sendable {
    package static let schemaVersion = 6
    package static let maximumCorrectionAttempts =
        QualityQualificationContract.maximumCorrectionRenders
    package static let maximumAttemptCount =
        QualityQualificationContract.maximumRenderPasses

    package let schemaVersion: Int
    package let engineVersion: String
    package let policyVersion: String
    package let evaluatorVersion: String
    package let planFingerprint: String
    package let sourceAttemptCount: Int
    package let attempts: [AutonomousCandidateAttempt]
    package let selectedAttemptIndex: Int?
    package let correctionCount: Int
    package let boundsValid: Bool
    package let incomingLiveMasterStateFingerprint: String?
    package let selectedOutgoingLiveMasterStateFingerprint: String?
    package let liveProposalFingerprint: String?

    package init(
        engineVersion: String,
        policyVersion: String,
        evaluatorVersion: String,
        planFingerprint: String,
        attempts sourceAttempts: [AutonomousCandidateAttempt],
        selectedAttemptIndex sourceSelectedAttemptIndex: Int?,
        correctionCount sourceCorrectionCount: Int
    ) {
        schemaVersion = Self.schemaVersion
        self.engineVersion = engineVersion
        self.policyVersion = policyVersion
        self.evaluatorVersion = evaluatorVersion
        self.planFingerprint = planFingerprint
        sourceAttemptCount = sourceAttempts.count

        let retainedAttempts = Array(sourceAttempts.prefix(Self.maximumAttemptCount))
        attempts = retainedAttempts
        selectedAttemptIndex = sourceSelectedAttemptIndex.flatMap {
            retainedAttempts.indices.contains($0) ? $0 : nil
        }
        let sourceCorrectionAttemptCount = sourceAttempts.filter {
            $0.kind == .correctionRender
        }.count
        correctionCount = min(Self.maximumCorrectionAttempts, max(0, sourceCorrectionCount))
        incomingLiveMasterStateFingerprint = retainedAttempts.first?
            .vector.incomingLiveMasterStateFingerprint
        selectedOutgoingLiveMasterStateFingerprint = selectedAttemptIndex.map {
            retainedAttempts[$0].vector.outgoingLiveMasterStateFingerprint
        }
        liveProposalFingerprint = retainedAttempts.first?
            .vector.liveProposalFingerprint
        boundsValid = sourceAttempts.count <= Self.maximumAttemptCount &&
            sourceCorrectionAttemptCount <= Self.maximumCorrectionAttempts &&
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
    private let transaction: AutonomousCandidateEvaluationTransaction

    init(_ transaction: AutonomousCandidateEvaluationTransaction) {
        self.transaction = transaction
    }

    @inline(never)
    func validate() -> Bool {
        guard transaction.schemaVersion ==
                AutonomousCandidateEvaluationTransaction.schemaVersion,
              transaction.boundsValid,
              transaction.engineVersion ==
                QualityQualificationContract.engineVersion,
              !transaction.policyVersion.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty,
              !transaction.evaluatorVersion.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty,
              !transaction.planFingerprint.isEmpty,
              transaction.sourceAttemptCount == transaction.attempts.count,
              (1...AutonomousCandidateEvaluationTransaction.maximumAttemptCount)
                .contains(transaction.attempts.count),
              let selectedIndex = transaction.selectedAttemptIndex,
              transaction.attempts.indices.contains(selectedIndex),
              selectedIndex == transaction.attempts.index(before:
                transaction.attempts.endIndex),
              transaction.attempts[0].kind == .initialRender,
              !transaction.attempts[0].forceHomeUpperTimbre,
              transaction.incomingLiveMasterStateFingerprint ==
                transaction.attempts[0].vector
                    .incomingLiveMasterStateFingerprint,
              transaction.selectedOutgoingLiveMasterStateFingerprint ==
                transaction.attempts[selectedIndex].vector
                    .outgoingLiveMasterStateFingerprint,
              transaction.liveProposalFingerprint ==
                transaction.attempts[0].vector.liveProposalFingerprint else {
            return false
        }

        for attempt in transaction.attempts {
            let vector = attempt.vector
            let signalSafetyValid = vector.fullMix.signalSafetyValid
            let hardGateSummaryIsCanonical =
                vector.hardGateSummaryIsCanonicalForTransactionValidation(
                    prevalidatedSignalSafetyValid: signalSafetyValid
                )
            guard vector.planFingerprint == transaction.planFingerprint,
                  vector.recordIsStructurallyValid(
                    prevalidatedHardGateSummaryIsCanonical:
                        hardGateSummaryIsCanonical
                  ) else {
                return false
            }
            let vectorIsComplete = vector.isComplete
            let vectorIsFinite = vector.isFinite
            guard attempt.isStructurallyComplete(
                prevalidatedRecordIsStructurallyValid: true,
                prevalidatedVectorIsComplete: vectorIsComplete,
                prevalidatedVectorIsFinite: vectorIsFinite,
                prevalidatedHardGatesPassed:
                    vector.hardGatesPassedForTransactionValidation(
                        prevalidatedVectorIsComplete: vectorIsComplete,
                        prevalidatedVectorIsFinite: vectorIsFinite,
                        prevalidatedSignalSafetyValid: signalSafetyValid
                    )
            ) else {
                return false
            }
        }

        if transaction.attempts.count == 1 {
            return selectedIndex == 0 && transaction.correctionCount == 0
        }
        guard transaction.attempts.count == 2,
              selectedIndex == 1,
              transaction.correctionCount == 1,
              transaction.attempts[1].kind == .correctionRender,
              transaction.attempts[1].forceHomeUpperTimbre else {
            return false
        }
        return correctionMatchesInitial(
            transaction.attempts[1].vector,
            transaction.attempts[0].vector
        )
    }

    @inline(never)
    private func correctionMatchesInitial(
        _ correction: AutonomousCandidateEvaluationVector,
        _ initial: AutonomousCandidateEvaluationVector
    ) -> Bool {
        correction.symbolic == initial.symbolic &&
            correction.graph == initial.graph &&
            correction.kickSyntax == initial.kickSyntax &&
            correction.foundationRhythm == initial.foundationRhythm &&
            correction.climaxArc == initial.climaxArc &&
            correction.modalPercussion == initial.modalPercussion &&
            correction.incomingLiveMasterRevision ==
                initial.incomingLiveMasterRevision &&
            correction.outgoingLiveMasterRevision ==
                initial.outgoingLiveMasterRevision &&
            correction.incomingLiveMasterTrimDB ==
                initial.incomingLiveMasterTrimDB &&
            correction.incomingLiveMasterCleanWindowCount ==
                initial.incomingLiveMasterCleanWindowCount &&
            correction.outgoingLiveMasterCleanWindowCount ==
                initial.outgoingLiveMasterCleanWindowCount &&
            correction.incomingLiveMasterStateFingerprint ==
                initial.incomingLiveMasterStateFingerprint &&
            correction.outgoingLiveMasterStateFingerprint ==
                initial.outgoingLiveMasterStateFingerprint &&
            correction.liveObservationFingerprint ==
                initial.liveObservationFingerprint &&
            correction.liveProposalFingerprint ==
                initial.liveProposalFingerprint &&
            correction.liveProposalOutcome == initial.liveProposalOutcome &&
            correction.requestedLiveMasterTrimDB ==
                initial.requestedLiveMasterTrimDB &&
            correction.appliedLiveMasterTrimDB ==
                initial.appliedLiveMasterTrimDB &&
            correction.liveMasterGain == initial.liveMasterGain &&
            correction.liveEarliestEligibleFutureSample ==
                initial.liveEarliestEligibleFutureSample &&
            correction.liveAppliedFutureSample ==
                initial.liveAppliedFutureSample &&
            correction.liveProposalBindingMatches ==
                initial.liveProposalBindingMatches &&
            sharedRouteInputsMatch(correction, initial) &&
            zip(correction.instruments, initial.instruments).allSatisfy {
                corrected, source in
                corrected.bar == source.bar &&
                    corrected.tonalEnvelopeExpansionEligible ==
                        source.tonalEnvelopeExpansionEligible &&
                    corrected.spectralRevealEligible ==
                        source.spectralRevealEligible
            } &&
            correction.percussionEchoTexture ==
                initial.percussionEchoTexture
    }

    @inline(never)
    private func sharedRouteInputsMatch(
        _ correction: AutonomousCandidateEvaluationVector,
        _ initial: AutonomousCandidateEvaluationVector
    ) -> Bool {
        let left = correction.routeContinuation
        let right = initial.routeContinuation
        return left.sampleRate == right.sampleRate &&
            left.channelCount == right.channelCount &&
            left.routeGeneration == right.routeGeneration &&
            left.routeFingerprint == right.routeFingerprint &&
            left.incomingContinuationFingerprint ==
                right.incomingContinuationFingerprint &&
            left.incomingQualityStateFingerprint ==
                right.incomingQualityStateFingerprint &&
            left.incomingKickCorrectionDB == right.incomingKickCorrectionDB &&
            left.incomingTopologyRevision == right.incomingTopologyRevision &&
            left.previousGraphFingerprint == right.previousGraphFingerprint &&
            left.routeRecovery == right.routeRecovery
    }
}

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
                    version: "candidate-continuation.v2",
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

package struct AutonomousLiveTargetStartEvidence: Codable, Equatable, Sendable {
    package enum Kind: String, Codable, Sendable {
        case noTransition = "no-transition"
        case scheduled
    }

    package enum Error: Swift.Error {
        case invalidSample
    }

    package let kind: Kind
    package let sample: Int64?

    package static let noTransition = Self(
        kind: .noTransition,
        sample: nil
    )

    package static func scheduled(
        sample: Int64
    ) throws -> Self {
        guard sample > 0 else { throw Error.invalidSample }
        return Self(kind: .scheduled, sample: sample)
    }

    package static func derived(
        incomingRevision: Int,
        outgoingRevision: Int,
        targetStartSample: Int64?
    ) -> Self? {
        let delta = outgoingRevision - incomingRevision
        if delta == 0, targetStartSample == nil { return .noTransition }
        guard delta == 1, let targetStartSample else { return nil }
        return try? .scheduled(sample: targetStartSample)
    }

    package var isComplete: Bool {
        switch kind {
        case .noTransition: sample == nil
        case .scheduled: sample.map { $0 > 0 } == true
        }
    }

    private init(kind: Kind, sample: Int64?) {
        self.kind = kind
        self.sample = sample
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case sample
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let sample = try container.decodeIfPresent(Int64.self, forKey: .sample)
        let candidate = Self(kind: kind, sample: sample)
        guard candidate.isComplete else {
            throw DecodingError.dataCorruptedError(
                forKey: .sample,
                in: container,
                debugDescription: "Invalid live target start evidence"
            )
        }
        self = candidate
    }
}

/// Final, post-decision identity for the exact atomic prepared phrase. It sits
/// outside the transaction so the finalized quality state can be bound without
/// creating a self-referential evidence fingerprint.
package struct AutonomousPreparedCommitProvenance: Codable, Equatable, Sendable {
    package static let schemaVersion = 2

    package let schemaVersion: Int
    package let candidateEvaluationFingerprint: String
    package let selectedSampleHash: String
    package let outgoingRenderDSPFingerprint: String
    package let outgoingQualityStateFingerprint: String
    package let outgoingLiveMasterStateFingerprint: String
    package let liveRevisionDelta: Int
    package let liveTargetStart: AutonomousLiveTargetStartEvidence
    package let fingerprint: String

    package var liveTargetStartSample: Int64? { liveTargetStart.sample }

    package init(
        candidateEvaluationFingerprint: String,
        selectedSampleHash: String,
        outgoingRenderDSPFingerprint: String,
        qualityState: QualityContinuationState,
        liveMasterHeadroomState: LiveMasterHeadroomContinuationState,
        liveRevisionDelta: Int,
        liveTargetStart: AutonomousLiveTargetStartEvidence
    ) {
        self.init(
            candidateEvaluationFingerprint: candidateEvaluationFingerprint,
            selectedSampleHash: selectedSampleHash,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            qualityState: qualityState,
            outgoingLiveMasterStateFingerprint:
                liveMasterHeadroomState.fingerprint,
            liveRevisionDelta: liveRevisionDelta,
            liveTargetStart: liveTargetStart
        )
    }

    package init(
        candidateEvaluationFingerprint: String,
        selectedSampleHash: String,
        outgoingRenderDSPFingerprint: String,
        qualityState: QualityContinuationState,
        outgoingLiveMasterStateFingerprint: String,
        liveRevisionDelta: Int,
        liveTargetStart: AutonomousLiveTargetStartEvidence
    ) {
        schemaVersion = Self.schemaVersion
        self.candidateEvaluationFingerprint = candidateEvaluationFingerprint
        self.selectedSampleHash = selectedSampleHash
        self.outgoingRenderDSPFingerprint = outgoingRenderDSPFingerprint
        outgoingQualityStateFingerprint =
            AutonomousCandidateFingerprint.qualityState(qualityState)
        self.outgoingLiveMasterStateFingerprint =
            outgoingLiveMasterStateFingerprint
        self.liveRevisionDelta = liveRevisionDelta
        self.liveTargetStart = liveTargetStart
        fingerprint = Self.fingerprint(
            candidateEvaluationFingerprint: candidateEvaluationFingerprint,
            selectedSampleHash: selectedSampleHash,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            outgoingQualityStateFingerprint: outgoingQualityStateFingerprint,
            outgoingLiveMasterStateFingerprint:
                outgoingLiveMasterStateFingerprint,
            liveRevisionDelta: liveRevisionDelta,
            liveTargetStart: liveTargetStart
        )
    }

    package var isComplete: Bool {
        schemaVersion == Self.schemaVersion &&
            !candidateEvaluationFingerprint.isEmpty && !selectedSampleHash.isEmpty &&
            !outgoingRenderDSPFingerprint.isEmpty &&
            !outgoingQualityStateFingerprint.isEmpty &&
            Self.isFingerprint(outgoingLiveMasterStateFingerprint) &&
            (0...1).contains(liveRevisionDelta) &&
            liveTargetStart.isComplete &&
            (liveRevisionDelta == 1) ==
                (liveTargetStart.kind == .scheduled) &&
            !fingerprint.isEmpty
    }

    package var isInternallyConsistent: Bool {
        isComplete && fingerprint == Self.fingerprint(
            candidateEvaluationFingerprint: candidateEvaluationFingerprint,
            selectedSampleHash: selectedSampleHash,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            outgoingQualityStateFingerprint: outgoingQualityStateFingerprint,
            outgoingLiveMasterStateFingerprint:
                outgoingLiveMasterStateFingerprint,
            liveRevisionDelta: liveRevisionDelta,
            liveTargetStart: liveTargetStart
        )
    }

    package func matches(
        candidateEvaluationFingerprint: String,
        selectedSampleHash: String,
        outgoingRenderDSPFingerprint: String,
        qualityState: QualityContinuationState,
        liveMasterHeadroomState: LiveMasterHeadroomContinuationState,
        liveRevisionDelta: Int,
        liveTargetStart: AutonomousLiveTargetStartEvidence
    ) -> Bool {
        matches(
            candidateEvaluationFingerprint: candidateEvaluationFingerprint,
            selectedSampleHash: selectedSampleHash,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            qualityState: qualityState,
            outgoingLiveMasterStateFingerprint:
                liveMasterHeadroomState.fingerprint,
            liveRevisionDelta: liveRevisionDelta,
            liveTargetStart: liveTargetStart
        )
    }

    package func matches(
        candidateEvaluationFingerprint: String,
        selectedSampleHash: String,
        outgoingRenderDSPFingerprint: String,
        qualityState: QualityContinuationState,
        outgoingLiveMasterStateFingerprint: String,
        liveRevisionDelta: Int,
        liveTargetStart: AutonomousLiveTargetStartEvidence
    ) -> Bool {
        isInternallyConsistent &&
            self.candidateEvaluationFingerprint == candidateEvaluationFingerprint &&
            self.selectedSampleHash == selectedSampleHash &&
            self.outgoingRenderDSPFingerprint == outgoingRenderDSPFingerprint &&
            outgoingQualityStateFingerprint ==
                AutonomousCandidateFingerprint.qualityState(qualityState) &&
            self.outgoingLiveMasterStateFingerprint ==
                outgoingLiveMasterStateFingerprint &&
            self.liveRevisionDelta == liveRevisionDelta &&
            self.liveTargetStart == liveTargetStart
    }

    private struct FingerprintPayload: Codable {
        let version: String
        let candidateEvaluationFingerprint: String
        let selectedSampleHash: String
        let outgoingRenderDSPFingerprint: String
        let outgoingQualityStateFingerprint: String
        let outgoingLiveMasterStateFingerprint: String
        let liveRevisionDelta: Int
        let liveTargetStart: AutonomousLiveTargetStartEvidence
    }

    private static func isFingerprint(_ value: String) -> Bool {
        value.utf8.count == 16 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }

    private static func fingerprint(
        candidateEvaluationFingerprint: String,
        selectedSampleHash: String,
        outgoingRenderDSPFingerprint: String,
        outgoingQualityStateFingerprint: String,
        outgoingLiveMasterStateFingerprint: String,
        liveRevisionDelta: Int,
        liveTargetStart: AutonomousLiveTargetStartEvidence
    ) -> String {
        AutonomousCandidateCanonicalJSON.fingerprint(FingerprintPayload(
            version: "prepared-commit.v2",
            candidateEvaluationFingerprint: candidateEvaluationFingerprint,
            selectedSampleHash: selectedSampleHash,
            outgoingRenderDSPFingerprint: outgoingRenderDSPFingerprint,
            outgoingQualityStateFingerprint: outgoingQualityStateFingerprint,
            outgoingLiveMasterStateFingerprint:
                outgoingLiveMasterStateFingerprint,
            liveRevisionDelta: liveRevisionDelta,
            liveTargetStart: liveTargetStart
        ))
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case candidateEvaluationFingerprint
        case selectedSampleHash
        case outgoingRenderDSPFingerprint
        case outgoingQualityStateFingerprint
        case outgoingLiveMasterStateFingerprint
        case liveRevisionDelta
        case liveTargetStart
        case fingerprint
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        candidateEvaluationFingerprint = try container.decode(
            String.self,
            forKey: .candidateEvaluationFingerprint
        )
        selectedSampleHash = try container.decode(
            String.self,
            forKey: .selectedSampleHash
        )
        outgoingRenderDSPFingerprint = try container.decode(
            String.self,
            forKey: .outgoingRenderDSPFingerprint
        )
        outgoingQualityStateFingerprint = try container.decode(
            String.self,
            forKey: .outgoingQualityStateFingerprint
        )
        outgoingLiveMasterStateFingerprint = try container.decode(
            String.self,
            forKey: .outgoingLiveMasterStateFingerprint
        )
        liveRevisionDelta = try container.decode(
            Int.self,
            forKey: .liveRevisionDelta
        )
        liveTargetStart = try container.decode(
            AutonomousLiveTargetStartEvidence.self,
            forKey: .liveTargetStart
        )
        fingerprint = try container.decode(String.self, forKey: .fingerprint)
        guard isInternallyConsistent else {
            throw DecodingError.dataCorruptedError(
                forKey: .fingerprint,
                in: container,
                debugDescription: "Prepared commit provenance mismatch"
            )
        }
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

    package static func combinedController(
        kickCorrectionDB: Double,
        liveMasterHeadroom: LiveMasterHeadroomContinuationState,
        proposalFingerprint: String?
    ) -> String {
        AutonomousTypedFingerprint.combinedController(
            kickCorrectionDB: kickCorrectionDB,
            liveMasterHeadroom: liveMasterHeadroom,
            proposalFingerprint: proposalFingerprint
        )
    }

    package static func combinedController(
        kickCorrectionDB: Double,
        liveMasterStateFingerprint: String,
        proposalFingerprint: String?
    ) -> String {
        AutonomousTypedFingerprint.combinedController(
            kickCorrectionDB: kickCorrectionDB,
            liveMasterStateFingerprint: liveMasterStateFingerprint,
            proposalFingerprint: proposalFingerprint
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
