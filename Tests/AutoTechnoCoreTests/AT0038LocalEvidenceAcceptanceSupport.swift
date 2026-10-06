import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation

/// Test-owned reconstruction of the existing descriptive projections. A witness
/// proves these bounded fields only; it is not item admission or perceptual quality.
struct AT0038LocalEvidenceWitness: Encodable, Equatable {
    let kick: ProfessionalQualityKickFoundationLocalEvidence
    let masking: ProfessionalQualityMaskingLocalEvidence
}

enum AT0038AcceptanceError: Error, Equatable {
    case invalidProjection
    case incompleteNativeBank
    case invalidCohortMembership
    case duplicateSourceBank
    case changedRerender
    case incompleteRerenders
    case oversizedProjection
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

/// A detached bounded collector over fresh typed banks. It never decodes a saved
/// trajectory or promotes descriptive measurements into a quality verdict.
struct AT0038LocalCohortAudit {
    struct Group: Encodable, Equatable {
        let checkpoint: CanonicalJourneyCheckpoint
        let sampleRate: Double
        let journeyCount: Int
        let noActivePairedBarsCount: Int
        let pairedBarHistogram: [Int: Int]
        let spreadSupportedJourneyCount: Int
    }

    struct Source: Encodable, Equatable {
        let seed: UInt64
        let bankFingerprint: String
        let reportFingerprints: [String]
    }

    struct Report: Encodable, Equatable {
        let schema = "autotechno-at0038-descriptive-cohort.v1"
        let engineVersion = QualityQualificationContract.engineVersion
        let evidenceVersion = ProfessionalEvidenceReportBank.evidenceVersion
        let sources: [Source]
        let rerenderedSeeds: [UInt64]
        let groups: [Group]
    }

    private struct Journey {
        let bankFingerprint: String
        let kick: [ProfessionalQualityKickFoundationLocalEvidence]
        let bytes: Data
    }

    let expectedSeeds: [UInt64]
    private var journeys: [UInt64: Journey] = [:]
    private var bankFingerprints = Set<String>()
    private var rerendered = Set<UInt64>()
    private var retainedBytes = 0
    private var requiredRerenders: [UInt64]?

    init(expectedSeeds: [UInt64]) throws {
        guard !expectedSeeds.isEmpty,
              expectedSeeds.count <= ProfessionalQualityCalibrationCorpus.maximumTrajectoryCount,
              Set(expectedSeeds).count == expectedSeeds.count else {
            throw AT0038AcceptanceError.invalidCohortMembership
        }
        self.expectedSeeds = expectedSeeds
    }

    mutating func append(seed: UInt64, bank: ProfessionalEvidenceReportBank) throws {
        guard expectedSeeds.contains(seed), journeys[seed] == nil else {
            throw AT0038AcceptanceError.invalidCohortMembership
        }
        let local = try AT0038LocalEvidenceAcceptanceSupport.reconstruct(bank)
        let fingerprint = try ProfessionalQualityCalibrationTrajectory(bank: bank).sourceBankFingerprint
        guard !bankFingerprints.contains(fingerprint) else {
            throw AT0038AcceptanceError.duplicateSourceBank
        }
        guard bank.reports.allSatisfy({ $0.fixtureFingerprint.hasPrefix("seed-\(seed).") }) else {
            throw AT0038AcceptanceError.invalidCohortMembership
        }
        let bytes = try AutonomousCandidateCanonicalJSON.data(local)
        guard bytes.count <= ProfessionalEvidenceReportBank.maximumEncodedBytes - retainedBytes else {
            throw AT0038AcceptanceError.oversizedProjection
        }
        journeys[seed] = Journey(bankFingerprint: fingerprint, kick: local.map(\.kick), bytes: bytes)
        bankFingerprints.insert(fingerprint)
        retainedBytes += bytes.count
    }

    func groups() throws -> [Group] {
        guard Set(journeys.keys) == Set(expectedSeeds),
              bankFingerprints.count == expectedSeeds.count else {
            throw AT0038AcceptanceError.invalidCohortMembership
        }
        return try ProfessionalQualityCalibrationProfile.requiredSampleRates.flatMap { rate in
            try CanonicalJourneyCheckpoint.allCases.map { checkpoint in
                let local = expectedSeeds.compactMap { seed in
                    journeys[seed]?.kick.first {
                        $0.checkpoint == checkpoint && $0.sampleRate == rate
                    }
                }
                guard local.count == expectedSeeds.count else {
                    throw AT0038AcceptanceError.invalidCohortMembership
                }
                return Group(checkpoint: checkpoint, sampleRate: rate,
                    journeyCount: local.count,
                    noActivePairedBarsCount: local.filter { $0.availability == .noActivePairedBars }.count,
                    pairedBarHistogram: Dictionary(grouping: local, by: \.pairedBarCount).mapValues(\.count),
                    spreadSupportedJourneyCount: local.filter { $0.pairedBarCount >= 2 }.count)
            }
        }
    }

    /// Include all supplied historical subjects plus current supported extrema.
    /// One pair has zero range but cannot establish within-checkpoint dispersion.
    mutating func requiredRerenderSeeds(historical: [UInt64]) throws -> [UInt64] {
        _ = try groups()
        guard requiredRerenders == nil, !historical.isEmpty,
              Set(historical).count == historical.count,
              Set(historical).isSubset(of: Set(expectedSeeds)) else {
            throw AT0038AcceptanceError.invalidCohortMembership
        }
        var required = Set(historical)
        for rate in ProfessionalQualityCalibrationProfile.requiredSampleRates {
            for checkpoint in CanonicalJourneyCheckpoint.allCases {
                let supported = expectedSeeds.compactMap { seed -> (UInt64, Double)? in
                    guard let local = journeys[seed]?.kick.first(where: {
                        $0.checkpoint == checkpoint && $0.sampleRate == rate
                    }), local.pairedBarCount >= 2, let spread = local.spreadDB else { return nil }
                    return (seed, spread)
                }
                required.formUnion(try Self.extremalSeeds(supported))
            }
        }
        let selected = expectedSeeds.filter { required.contains($0) }
        requiredRerenders = selected
        return selected
    }

    static func extremalSeeds(_ supported: [(UInt64, Double)]) throws -> Set<UInt64> {
        guard supported.allSatisfy({ $0.1.isFinite }),
              Set(supported.map { $0.0 }).count == supported.count else {
            throw AT0038AcceptanceError.invalidProjection
        }
        guard let minimum = supported.map({ $0.1 }).min(),
              let maximum = supported.map({ $0.1 }).max() else { return [] }
        return Set(supported.filter { $0.1 == minimum || $0.1 == maximum }.map { $0.0 })
    }

    mutating func verifyRerender(seed: UInt64, bank: ProfessionalEvidenceReportBank) throws {
        guard requiredRerenders?.contains(seed) == true,
              let original = journeys[seed], !rerendered.contains(seed) else {
            throw AT0038AcceptanceError.invalidCohortMembership
        }
        let local = try AT0038LocalEvidenceAcceptanceSupport.reconstruct(bank)
        let fingerprint = try ProfessionalQualityCalibrationTrajectory(bank: bank).sourceBankFingerprint
        guard fingerprint == original.bankFingerprint, local.map(\.kick) == original.kick,
              try AutonomousCandidateCanonicalJSON.data(local) == original.bytes else {
            throw AT0038AcceptanceError.changedRerender
        }
        rerendered.insert(seed)
    }

    func encodedCompletedReport() throws -> Data {
        try AutonomousCandidateCanonicalJSON.data(completedReport())
    }

    func completedReport() throws -> Report {
        let groups = try finish()
        let sources = try expectedSeeds.map { seed -> Source in
            guard let original = journeys[seed] else {
                throw AT0038AcceptanceError.invalidCohortMembership
            }
            return Source(seed: seed, bankFingerprint: original.bankFingerprint,
                reportFingerprints: original.kick.map(\.sourceReportFingerprint))
        }
        return Report(sources: sources,
            rerenderedSeeds: expectedSeeds.filter { rerendered.contains($0) }, groups: groups)
    }

    func finish() throws -> [Group] {
        let result = try groups()
        guard let requiredRerenders, !requiredRerenders.isEmpty,
              Set(requiredRerenders).count == requiredRerenders.count,
              Set(requiredRerenders).isSubset(of: Set(expectedSeeds)),
              rerendered == Set(requiredRerenders) else {
            throw AT0038AcceptanceError.incompleteRerenders
        }
        return result
    }
}

/// Mechanistic controls for the future complete producer. A supplied profile is
/// a source of existing bounds, not proof of current artifact qualification.
/// The parent producer must separately authenticate its complete native context.
enum AT0038LocalFixtureAcceptanceSupport {
    struct PairedKickMeanControl {
        let uniformSource: [ProfessionalQualityKickFoundationLocalEvidence.SourceBar]
        let localizedSource: [ProfessionalQualityKickFoundationLocalEvidence.SourceBar]
        let uniform: ProfessionalQualityKickFoundationLocalEvidence
        let localized: ProfessionalQualityKickFoundationLocalEvidence
        let profileFingerprint: String
        let targetMeanDB: Double
    }

    static func pairedKickMeanControl(
        profile: ProfessionalQualityCalibrationProfile,
        checkpoint: CanonicalJourneyCheckpoint, sampleRate: Double
    ) throws -> PairedKickMeanControl {
        guard profile.isComplete,
              profile.engineVersion == QualityQualificationContract.engineVersion,
              profile.sampleRates.contains(sampleRate),
              ProfessionalQualityCalibrationProfile.requiredSampleRates.contains(sampleRate),
              let bounds = profile[checkpoint]?[.kickOverFoundationActiveDBMean] else {
            throw AT0038AcceptanceError.invalidProjection
        }
        let target = bounds.lower + (bounds.upper - bounds.lower) * 0.5
        // Keep the +/-20 dB construction inside the existing +/-120 dB
        // descriptive measurement range. This is fixture geometry, not policy.
        guard target.isFinite, abs(target) < 100 else {
            throw AT0038AcceptanceError.invalidProjection
        }
        let ratio = pow(10, target / 20)
        let uniformSource = (8...11).map {
            ProfessionalQualityKickFoundationLocalEvidence.SourceBar(
                bar: $0, kickActiveRMS: ratio, foundationActiveRMS: 1)
        }
        let localizedSource = [ratio * 0.1, ratio, ratio, ratio * 10].enumerated().map {
            ProfessionalQualityKickFoundationLocalEvidence.SourceBar(
                bar: 8 + $0.offset, kickActiveRMS: $0.element, foundationActiveRMS: 1)
        }
        func report(_ bars: [ProfessionalQualityKickFoundationLocalEvidence.SourceBar],
                    identity: String) throws -> ProfessionalQualityKickFoundationLocalEvidence {
            try ProfessionalQualityKickFoundationLocalEvidence(
                engineVersion: profile.engineVersion,
                policyVersion: "at0038-mechanistic-mean-control.v1",
                sourceReportFingerprint: profile.fingerprint + ":" + identity,
                planFingerprint: "at0038-matched-mean-fixture.v1",
                checkpoint: checkpoint, sampleRate: sampleRate,
                sourceBarCount: bars.count, sourceBars: bars)
        }
        let uniform = try report(uniformSource, identity: "uniform-source")
        let localized = try report(localizedSource, identity: "localized-source")
        guard let uniformMean = uniform.meanDB, let localMean = localized.meanDB,
              let uniformBounds = profile.effectiveBounds(for: .kickOverFoundationActiveDBMean,
                at: checkpoint, observedValue: uniformMean),
              let localBounds = profile.effectiveBounds(for: .kickOverFoundationActiveDBMean,
                at: checkpoint, observedValue: localMean),
              uniformBounds.contains(uniformMean), localBounds.contains(localMean),
              uniform.spreadDB == 0, (localized.spreadDB ?? 0) > 0 else {
            throw AT0038AcceptanceError.invalidProjection
        }
        return PairedKickMeanControl(uniformSource: uniformSource,
            localizedSource: localizedSource, uniform: uniform, localized: localized,
            profileFingerprint: profile.fingerprint, targetMeanDB: target)
    }

    /// One existing two-bar, three-role-pair/four-band fixture recipe shared
    /// by localization and canonical-profile non-compensation controls.
    static func maskingFixture(activeBar: Int, activeBand: String,
        maximumOverlap: Double = 0.8, checkpoint: CanonicalJourneyCheckpoint = .establishment,
        sampleRate: Double = 44_100) throws -> ProfessionalQualityMaskingLocalEvidence {
        let bars = [50, 51].map { bar in
            let observations = SpectrumMaskingAnalyzer.rolePairs.flatMap { pair in
                SpectrumMaskingAnalyzer.bands.map { band in
                    let active = bar == activeBar && band.name == activeBand &&
                        pair.0 == .foundation && pair.1 == .percussion
                    return AutonomousMaskingObservationEvidence(
                        bandName: band.name, lowerHz: band.lowerHz, upperHz: band.upperHz,
                        firstRole: pair.0.rawValue, secondRole: pair.1.rawValue,
                        analyzedWindowCount: SpectrumMaskingAnalyzer.analyzedWindowCount,
                        activePairWindowCount: active ? 2 : 0,
                        overlapWindowCount: active ? 1 : 0,
                        longestOverlapRun: active ? 1 : 0,
                        maximumOverlap: active ? maximumOverlap : 0)
                }
            }
            return AutonomousMaskingBarEvidence(bar: bar,
                sourceObservationCount: observations.count, observations: observations)
        }
        return try ProfessionalQualityMaskingLocalEvidence(
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: "masking-local-test.v1", sourceReportFingerprint: "same-candidate-source",
            planFingerprint: "same-plan", checkpoint: checkpoint, sampleRate: sampleRate,
            sourceBars: bars)
    }

    /// Retain the canonical observation and evaluator. Only the three existing
    /// masking aggregates are reconstructed from the known local fixture source.
    static func maskingFixtureVerdict(_ local: ProfessionalQualityMaskingLocalEvidence,
        baseline: ProfessionalQualityObservation, profile: ProfessionalQualityCalibrationProfile
    ) throws -> ProfessionalQualityVerdict {
        guard local.engineVersion == baseline.engineVersion,
              local.checkpoint == baseline.checkpoint, local.sampleRate == baseline.sampleRate,
              !local.observations.isEmpty,
              local.observations.allSatisfy({
                  $0.analyzedWindowCount == SpectrumMaskingAnalyzer.analyzedWindowCount
              }) else { throw AT0038AcceptanceError.invalidProjection }
        let analyzed = local.observations.reduce(0) { $0 + $1.analyzedWindowCount }
        var observation = try baseline.replacing(.maskingMaximumOverlap,
            with: local.observations.map(\.maximumOverlap).max() ?? 0)
        observation = try observation.replacing(.maskingOverlapWindowRatio,
            with: Double(local.observations.reduce(0) { $0 + $1.overlapWindowCount }) / Double(analyzed))
        observation = try observation.replacing(.maskingLongestRunRatio,
            with: Double(local.observations.map(\.longestOverlapRun).max() ?? 0) /
                Double(SpectrumMaskingAnalyzer.analyzedWindowCount))
        return ProfessionalQualityProfileEvaluator.evaluate(observation, against: profile)
    }
}
