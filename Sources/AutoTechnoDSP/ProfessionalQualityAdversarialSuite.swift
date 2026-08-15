import AutoTechnoCore
import Foundation

package enum ProfessionalQualityAdversarialScenario: String, CaseIterable,
        Codable, Sendable {
    case hardGateCompensation = "hard-gate-compensation"
    case truePeakCompensation = "true-peak-compensation"
    case flattenedTrajectory = "flattened-trajectory"
    case spectralCollapse = "spectral-collapse"
    case maskingFlood = "masking-flood"
    case lowEndPhaseFailure = "low-end-phase-failure"
    case silentProxy = "silent-proxy"
    case foreignRate = "foreign-rate"
    case trajectoryFlattening = "trajectory-flattening"
    case rateDrift = "rate-drift"
}

package struct ProfessionalQualityAdversarialCaseResult: Codable, Equatable,
        Sendable {
    package let scenario: ProfessionalQualityAdversarialScenario
    package let rejected: Bool
    package let expectedReason: ProfessionalQualityRejection
    package let actualReasons: [ProfessionalQualityRejection]
    package let failedMetrics: [ProfessionalQualityMetric]

    package var passed: Bool {
        rejected && actualReasons.contains(expectedReason)
    }
}

/// A deterministic attack on the calibrated policy surface. The suite stores
/// only reason-coded outcomes, not the source observations or reconstructable
/// evidence. Every scenario must be rejected independently.
package struct ProfessionalQualityAdversarialSuiteReport: Codable, Equatable,
        Sendable {
    package static let legacySchemaVersion = 1
    package static let schemaVersion = 2
    package static let legacySuiteVersion =
        "autotechno-professional-quality-adversarial.v1"
    package static let suiteVersion =
        "autotechno-professional-quality-adversarial.v2"

    package let schemaVersion: Int
    package let suiteVersion: String
    package let profileFingerprint: String
    package let sourceObservationCount: Int
    package let baselineAcceptanceCount: Int
    package let cases: [ProfessionalQualityAdversarialCaseResult]

    package init(
        profile: ProfessionalQualityCalibrationProfile,
        sourceObservations: [ProfessionalQualityObservation]
    ) throws {
        let expectedSourceObservationCount = profile.checkpoints.first
            .map { $0.sourceObservationCount *
                CanonicalJourneyCheckpoint.allCases.count } ?? 0
        guard profile.isComplete, !profile.fingerprint.isEmpty,
              sourceObservations.count == expectedSourceObservationCount,
              sourceObservations.allSatisfy({
                  ProfessionalQualityProfileEvaluator.evaluate(
                      $0, against: profile
                  ).accepted
              }) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        guard let baseline = sourceObservations.first(where: {
            $0.sampleRate == 48_000 && $0.checkpoint == .establishment
        }) else {
            throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
        }

        var generated: [ProfessionalQualityAdversarialCaseResult] = []
        func append(
            _ scenario: ProfessionalQualityAdversarialScenario,
            observation: ProfessionalQualityObservation,
            expected: ProfessionalQualityRejection
        ) {
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                observation, against: profile
            )
            generated.append(ProfessionalQualityAdversarialCaseResult(
                scenario: scenario,
                rejected: !verdict.accepted,
                expectedReason: expected,
                actualReasons: verdict.reasons,
                failedMetrics: verdict.failedMetrics
            ))
        }
        func outside(
            _ metric: ProfessionalQualityMetric,
            preferLower: Bool
        ) throws -> Double {
            guard let checkpoint = profile[baseline.checkpoint],
                  let bounds = checkpoint[metric] else {
                throw ProfessionalQualityCalibrationError.invalidMetricSet
            }
            let distance = max(1e-9, abs(bounds.upper - bounds.lower) * 0.1)
            return preferLower ? bounds.lower - distance : bounds.upper + distance
        }
        func identityCopy(
            sampleRate: Double = baseline.sampleRate,
            hardGatesPassed: Bool = true,
            metrics: [ProfessionalQualityMetricValue]? = nil
        ) throws -> ProfessionalQualityObservation {
            try ProfessionalQualityObservation(
                engineVersion: baseline.engineVersion,
                evidenceVersion: baseline.evidenceVersion,
                checkpoint: baseline.checkpoint,
                sampleRate: sampleRate,
                hardGatesPassed: hardGatesPassed,
                metrics: metrics ?? baseline.metrics
            )
        }

        append(
            .hardGateCompensation,
            observation: try identityCopy(hardGatesPassed: false),
            expected: .hardGateFailure
        )
        append(
            .truePeakCompensation,
            observation: try baseline.replacing(
                .truePeakDBTP,
                with: outside(.truePeakDBTP, preferLower: false)
            ),
            expected: .metricOutOfRange
        )

        let trajectoryCheckpoint = try Self.checkpointWithLargestLowerBound(
            metric: .movementScore,
            profile: profile
        )
        let trajectoryBaseline = try Self.baseline(
            checkpoint: trajectoryCheckpoint,
            observations: sourceObservations
        )
        guard let trajectoryBounds = profile[trajectoryCheckpoint]?[.movementScore],
              trajectoryBounds.lower > 0 else {
            throw ProfessionalQualityCalibrationError.invalidBounds
        }
        append(
            .flattenedTrajectory,
            observation: try trajectoryBaseline.replacing(
                .movementScore,
                with: trajectoryBounds.lower - max(1e-9,
                    trajectoryBounds.lower * 0.1)
            ),
            expected: .metricOutOfRange
        )

        append(
            .spectralCollapse,
            observation: try baseline.replacing(
                .spectralCentroidMeanHz,
                with: outside(.spectralCentroidMeanHz, preferLower: true)
            ),
            expected: .metricOutOfRange
        )
        append(
            .maskingFlood,
            observation: try baseline.replacing(
                .maskingMaximumOverlap,
                with: outside(.maskingMaximumOverlap, preferLower: false)
            ),
            expected: .metricOutOfRange
        )
        append(
            .lowEndPhaseFailure,
            observation: try baseline.replacing(
                .lowStereoCorrelation,
                with: outside(.lowStereoCorrelation, preferLower: true)
            ),
            expected: .metricOutOfRange
        )

        var silenceMetrics = baseline.metrics
        let silentValues: [ProfessionalQualityMetric: Double] = [
            .integratedLoudnessLUFS: -120,
            .maximumMomentaryLoudnessLUFS: -120,
            .maximumShortTermLoudnessLUFS: -120,
            .activeWindowRatio: 0,
            .movementScore: 0,
            .spectralCentroidMeanHz: 0,
            .spectralCentroidSpreadHz: 0,
            .spectralBandwidthMeanHz: 0,
            .spectralRolloff85MeanHz: 0,
            .positiveSpectralFluxMean: 0,
            .positiveSpectralFluxPeak: 0,
            .rmsTrajectoryDeltaMeanDB: 0,
            .rmsTrajectoryDeltaPeakDB: 0,
        ]
        silenceMetrics = silenceMetrics.map { value in
            silentValues[value.metric].map {
                ProfessionalQualityMetricValue(metric: value.metric, value: $0)
            } ?? value
        }
        append(
            .silentProxy,
            observation: try identityCopy(metrics: silenceMetrics),
            expected: .metricOutOfRange
        )
        append(
            .foreignRate,
            observation: try identityCopy(sampleRate: 96_000),
            expected: .profileMismatch
        )
        let trajectoryAttack = try Self.trajectoryAttack(
            profile: profile,
            observations: sourceObservations
        )
        let trajectoryFailures = ProfessionalQualityRelationshipEvaluator
            .evaluate(observations: trajectoryAttack, against: profile)
            .filter { $0.kind == .trajectory }
        generated.append(ProfessionalQualityAdversarialCaseResult(
            scenario: .trajectoryFlattening,
            rejected: !trajectoryFailures.isEmpty,
            expectedReason: .trajectoryRelationshipFailed,
            actualReasons: trajectoryFailures.isEmpty
                ? [] : [.trajectoryRelationshipFailed],
            failedMetrics: Array(Set(trajectoryFailures.map(\.metric)))
                .sorted { $0.rawValue < $1.rawValue }
        ))

        let rateAttack = try Self.rateAttack(
            profile: profile,
            observations: sourceObservations
        )
        let rateFailures = ProfessionalQualityRelationshipEvaluator
            .evaluate(observations: rateAttack, against: profile)
            .filter { $0.kind == .rateConsistency }
        generated.append(ProfessionalQualityAdversarialCaseResult(
            scenario: .rateDrift,
            rejected: !rateFailures.isEmpty,
            expectedReason: .rateConsistencyFailed,
            actualReasons: rateFailures.isEmpty ? [] : [.rateConsistencyFailed],
            failedMetrics: Array(Set(rateFailures.map(\.metric)))
                .sorted { $0.rawValue < $1.rawValue }
        ))

        schemaVersion = profile.usesDiverseCalibration
            ? Self.schemaVersion : Self.legacySchemaVersion
        suiteVersion = profile.usesDiverseCalibration
            ? Self.suiteVersion : Self.legacySuiteVersion
        profileFingerprint = profile.fingerprint
        sourceObservationCount = sourceObservations.count
        baselineAcceptanceCount = sourceObservations.count
        cases = generated.sorted { $0.scenario.rawValue < $1.scenario.rawValue }
    }

    package init(
        profile: ProfessionalQualityCalibrationProfile,
        sourceCorpus: ProfessionalQualityCalibrationCorpus
    ) throws {
        guard profile.usesDiverseCalibration,
              sourceCorpus.isComplete,
              sourceCorpus.sourceTrajectoryCount ==
                profile.sourceTrajectoryCount,
              sourceCorpus.fingerprint == profile.sourceBankFingerprint,
              sourceCorpus.trajectories.allSatisfy({ trajectory in
                  ProfessionalQualityRelationshipEvaluator.evaluate(
                      observations: trajectory.observations,
                      against: profile
                  ).isEmpty
              }) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        try self.init(
            profile: profile,
            sourceObservations: sourceCorpus.observations
        )
    }

    package var passed: Bool {
        let recognizedVersion =
            (schemaVersion == Self.legacySchemaVersion &&
                suiteVersion == Self.legacySuiteVersion) ||
            (schemaVersion == Self.schemaVersion &&
                suiteVersion == Self.suiteVersion)
        return recognizedVersion &&
            !profileFingerprint.isEmpty && sourceObservationCount > 0 &&
            baselineAcceptanceCount == sourceObservationCount &&
            cases.count == ProfessionalQualityAdversarialScenario.allCases.count &&
            cases.map(\.scenario) == ProfessionalQualityAdversarialScenario
                .allCases.sorted { $0.rawValue < $1.rawValue } &&
            cases.allSatisfy(\.passed)
    }

    package func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    package static func decodeDeterministicJSON(
        _ data: Data
    ) throws -> ProfessionalQualityAdversarialSuiteReport {
        let decoded = try JSONDecoder().decode(
            ProfessionalQualityAdversarialSuiteReport.self,
            from: data
        )
        guard decoded.passed,
              try decoded.deterministicJSON() == data else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return decoded
    }

    package var fingerprint: String {
        guard let data = try? deterministicJSON(),
              let string = String(data: data, encoding: .utf8) else { return "" }
        var sink = StreamingFNV1a()
        sink.domain(schemaVersion == Self.schemaVersion
            ? "professional-quality-adversarial-suite-json.v2"
            : "professional-quality-adversarial-suite-json.v1")
        sink.string(string)
        return fixedWidthFingerprintHex(sink.value)
    }

    private static func checkpointWithLargestLowerBound(
        metric: ProfessionalQualityMetric,
        profile: ProfessionalQualityCalibrationProfile
    ) throws -> CanonicalJourneyCheckpoint {
        guard let result = profile.checkpoints.compactMap({ checkpoint in
            checkpoint[metric].map { (checkpoint.checkpoint, $0.lower) }
        }).max(by: { $0.1 < $1.1 }) else {
            throw ProfessionalQualityCalibrationError.invalidMetricSet
        }
        return result.0
    }

    private static func baseline(
        checkpoint: CanonicalJourneyCheckpoint,
        observations: [ProfessionalQualityObservation]
    ) throws -> ProfessionalQualityObservation {
        guard let observation = observations.first(where: {
            $0.checkpoint == checkpoint && $0.sampleRate == 48_000
        }) else {
            throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
        }
        return observation
    }

    private static func trajectoryAttack(
        profile: ProfessionalQualityCalibrationProfile,
        observations: [ProfessionalQualityObservation]
    ) throws -> [ProfessionalQualityObservation] {
        for relation in profile.trajectories {
            let pair = relation.trajectory.checkpoints
            guard let fromIndex = observations.firstIndex(where: {
                $0.sampleRate == 48_000 && $0.checkpoint == pair.from
            }), let toIndex = observations.firstIndex(where: {
                $0.sampleRate == 48_000 && $0.checkpoint == pair.to
            }), let fromBounds = profile[pair.from]?[relation.metric],
                  let toBounds = profile[pair.to]?[relation.metric] else {
                continue
            }
            let candidatePairs = [
                (fromBounds.lower, toBounds.upper),
                (fromBounds.upper, toBounds.lower),
            ]
            for (fromValue, toValue) in candidatePairs {
                var mutated = observations
                mutated[fromIndex] = try mutated[fromIndex].replacing(
                    relation.metric, with: fromValue
                )
                mutated[toIndex] = try mutated[toIndex].replacing(
                    relation.metric, with: toValue
                )
                let locallyAccepted = [fromIndex, toIndex].allSatisfy {
                    ProfessionalQualityProfileEvaluator.evaluate(
                        mutated[$0], against: profile
                    ).accepted
                }
                let relationshipFailed = ProfessionalQualityRelationshipEvaluator
                    .evaluate(observations: mutated, against: profile)
                    .contains {
                        $0.kind == .trajectory &&
                            $0.trajectory == relation.trajectory &&
                            $0.metric == relation.metric
                    }
                if locallyAccepted && relationshipFailed { return mutated }
            }
        }
        throw ProfessionalQualityCalibrationError.invalidBounds
    }

    private static func rateAttack(
        profile: ProfessionalQualityCalibrationProfile,
        observations: [ProfessionalQualityObservation]
    ) throws -> [ProfessionalQualityObservation] {
        for rateBound in profile.rateConsistency {
            guard let lowIndex = observations.firstIndex(where: {
                $0.sampleRate == profile.sampleRates[0] &&
                    $0.checkpoint == rateBound.checkpoint
            }), let highIndex = observations.firstIndex(where: {
                $0.sampleRate == profile.sampleRates[1] &&
                    $0.checkpoint == rateBound.checkpoint
            }), let metricBounds = profile[rateBound.checkpoint]?[rateBound.metric]
            else { continue }
            var mutated = observations
            mutated[lowIndex] = try mutated[lowIndex].replacing(
                rateBound.metric, with: metricBounds.lower
            )
            mutated[highIndex] = try mutated[highIndex].replacing(
                rateBound.metric, with: metricBounds.upper
            )
            let locallyAccepted = [lowIndex, highIndex].allSatisfy {
                ProfessionalQualityProfileEvaluator.evaluate(
                    mutated[$0], against: profile
                ).accepted
            }
            let relationshipFailed = ProfessionalQualityRelationshipEvaluator
                .evaluate(observations: mutated, against: profile)
                .contains {
                    $0.kind == .rateConsistency &&
                        $0.checkpoint == rateBound.checkpoint &&
                        $0.metric == rateBound.metric
                }
            if locallyAccepted && relationshipFailed { return mutated }
        }
        throw ProfessionalQualityCalibrationError.invalidBounds
    }
}
