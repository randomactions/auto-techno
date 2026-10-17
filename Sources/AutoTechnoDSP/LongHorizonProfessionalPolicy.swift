import AutoTechnoCore
import Foundation

/// Exact identity and minimum evidence contract for the first hour-scale
/// professional policy. Phrase-local signal quality remains owned by the
/// existing primary evaluator; this policy judges only cross-phrase and
/// cross-episode relationships.
package enum LongHorizonProfessionalPolicySchema {
  package static let observationVersion =
    "autotechno-long-horizon-policy-observation.v8"
  package static let corpusVersion =
    "autotechno-long-horizon-policy-corpus.v8"
  package static let profileVersion =
    "autotechno-long-horizon-professional-profile.v22"
  package static let adversarialVersion =
    "autotechno-long-horizon-adversarial.v22"
  package static let holdoutVersion =
    "autotechno-long-horizon-holdout.v22"
  package static let policyFamilyVersion =
    "autotechno-long-horizon.primary-calibrated.v22"
  package static let minimumDevelopmentJourneyCount = 7
  package static let minimumHoldoutJourneyCount = 2
  package static let minimumJourneyBars = 7_200
  package static let minimumSignalObservationCount = 12
  package static let minimumOperatorTransitionCount = 2
  package static let minimumSignalRateCount = 2
  /// A pending token cannot match an actual evaluator's sealed identity.
  /// Local policy fixtures can exercise reduction without manufacturing seals.
  package static var requiredPrimaryPolicyVersion: String {
    guard let profile = ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint,
      let adversarial = ProfessionalQualityPrimaryArtifacts.expectedAdversarialSuiteFingerprint,
      let holdout = ProfessionalQualityPrimaryArtifacts.expectedHoldoutQualificationFingerprint
    else { return ProfessionalQualityPrimaryEvaluator.policyFamilyVersion + ".unqualified" }
    return [ProfessionalQualityPrimaryEvaluator.policyFamilyVersion,
      "profile-\(profile)", "adversarial-\(adversarial)", "holdout-\(holdout)"].joined(separator: ".")
  }
}

package enum LongHorizonProfessionalPolicyError: Error, Equatable, Sendable {
  case invalidEvidence
  case insufficientEvidence
  case duplicateJourney
  case incompatibleJourney
  case profileMismatch
  case adversarialFailure
  case holdoutFailure
  case nonCanonicalJSON
}

package enum LongHorizonPolicySemanticMetric: String, CaseIterable, Codable,
  Sendable
{
  case highTensionDwellBars = "high-tension-dwell-bars"
  case recoveryBarRatio = "recovery-bar-ratio"
  case dominantSemanticPeriodicity = "dominant-semantic-periodicity"
  case eventSignatureRepeatRatio = "event-signature-repeat-ratio"
  case matchedIdentityRecallRatio = "matched-identity-recall-ratio"
  case zeroAgeDebtRatio = "zero-age-debt-ratio"
  case overdueDebtCount = "overdue-debt-count"
  case oldestDebtAgeBars = "oldest-debt-age-bars"
  case maximumCapabilityRunBars = "maximum-capability-run-bars"
}

package struct LongHorizonPolicyNamedValue: Codable, Equatable, Sendable {
  package let metric: LongHorizonPolicySemanticMetric
  package let value: Double
}

package struct LongHorizonPolicyBounds: Codable, Equatable, Sendable {
  package let lower: Double
  package let upper: Double

  package init(lower: Double, upper: Double) throws {
    guard lower.isFinite, upper.isFinite, lower <= upper else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
    self.lower = lower
    self.upper = upper
  }

  package func contains(_ value: Double) -> Bool {
    value.isFinite && value >= lower && value <= upper
  }
}

package struct LongHorizonPolicySemanticBound: Codable, Equatable, Sendable {
  package let metric: LongHorizonPolicySemanticMetric
  package let bounds: LongHorizonPolicyBounds
}

package struct LongHorizonPolicyOperatorDelta: Codable, Equatable, Sendable {
  package let sampleRate: Double
  package let operatorKind: LongHorizonEpisodeOperator
  package let metric: LongHorizonSignalMetric
  package let transitionCount: Int
  package let meanDelta: Double
}

package struct LongHorizonPolicyOperatorDeltaBound: Codable, Equatable,
  Sendable
{
  package let sampleRate: Double
  package let operatorKind: LongHorizonEpisodeOperator
  package let metric: LongHorizonSignalMetric
  package let bounds: LongHorizonPolicyBounds
}

package struct LongHorizonPolicyEffectObservation: Codable, Equatable,
  Sendable
{
  package let family: LongHorizonEffectFamily
  package let observedBarCount: Int
  package let eligibleBarCount: Int
  package let activeBarCount: Int
  package let tailOnlyBarCount: Int
  package let recoveryCount: Int
  package let maximumActiveRunBars: Int
  package let wetBarOccupancy: Double
  package let maximumReturnToSourceDB: Double?
  package let materialWorldCount: Int?
  package let meanEffectWorldDistance: Double?
  package let maximumEffectWorldDistance: Double?
}

package struct LongHorizonPolicyEffectBound: Codable, Equatable, Sendable {
  package let family: LongHorizonEffectFamily
  package let maximumWetBarOccupancy: Double
  package let maximumTailBarOccupancy: Double
  package let maximumActiveRunBars: Int
  package let maximumReturnToSourceDB: Double?
  package let minimumMaterialWorldCount: Int?
  package let maximumMeanEffectWorldDistance: Double?
  package let maximumEffectWorldDistance: Double?
}

/// One root retains both independently accepted native histories. No semantic,
/// signal or effect measurement is averaged or copied between routes.
package struct LongHorizonPolicyObservation: Codable, Equatable, Sendable {
  package let schemaVersion: String
  package let engineVersion: String
  package let primaryPolicyVersion: String
  package let rootSeed: UInt64
  package let routes: [LongHorizonRuntimePolicyObservation]
  package let sourceFingerprint: String

  package var sampleRates: [Double] { routes.map(\.sampleRate) }
  package var operatorDeltas: [LongHorizonPolicyOperatorDelta] { routes.flatMap(\.operatorDeltas) }

  package init(routeObservations: [LongHorizonRuntimePolicyObservation]) throws {
    self.init(uncheckedRoutes: routeObservations)
    guard isComplete, routes.allSatisfy(\.hasMinimumDecisionEvidence)
    else { throw LongHorizonProfessionalPolicyError.incompatibleJourney }
  }

  /// Construction alone grants no authority: decoding, corpus fitting and
  /// evaluation all verify the complete pair and each route's source binding.
  package init(uncheckedRoutes: [LongHorizonRuntimePolicyObservation]) {
    schemaVersion = LongHorizonProfessionalPolicySchema.observationVersion
    routes = uncheckedRoutes.sorted { $0.sampleRate < $1.sampleRate }
    engineVersion = routes.first?.engineVersion ?? ""
    primaryPolicyVersion = routes.first?.primaryPolicyVersion ?? ""
    rootSeed = routes.first?.rootSeed ?? 0
    sourceFingerprint = Self.fingerprint(routes)
  }

  package var isComplete: Bool {
    schemaVersion == LongHorizonProfessionalPolicySchema.observationVersion
      && engineVersion == QualityQualificationContract.engineVersion
      && primaryPolicyVersion == LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion
      && sampleRates == [44_100, 48_000]
      && routes.allSatisfy {
        $0.isStructurallyComplete && $0.engineVersion == engineVersion
          && $0.primaryPolicyVersion == primaryPolicyVersion && $0.rootSeed == rootSeed
          && $0.signalObservationCount == $0.observedPhraseCount
          && $0.signalObservationCount >= LongHorizonProfessionalPolicySchema.minimumSignalObservationCount
          && $0.signalOmittedPhraseCount == 0
          && $0.operatorDeltas.allSatisfy {
            $0.transitionCount >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
          }
      }
      && sourceFingerprint == Self.fingerprint(routes)
  }

  private static func fingerprint(_ routes: [LongHorizonRuntimePolicyObservation]) -> String {
    var hasher = LongHorizonPolicyHasher()
    hasher.mix(LongHorizonProfessionalPolicySchema.observationVersion)
    for route in routes { hasher.mix(route.sampleRate); hasher.mix(route.sourceFingerprint) }
    return hasher.hex
  }

  package func deterministicJSON() throws -> Data { try LongHorizonPolicyJSON.encode(self) }

  package static func decodeDeterministicJSON(_ data: Data) throws -> Self {
    let decoded = try JSONDecoder().decode(Self.self, from: data)
    guard decoded.isComplete, try decoded.deterministicJSON() == data
    else { throw LongHorizonProfessionalPolicyError.nonCanonicalJSON }
    return decoded
  }

  package static func semanticValues(
    from report: LongHorizonSemanticTrajectoryReport
  ) throws -> [LongHorizonPolicyNamedValue] {
    let periodicity = report.dominantSemanticPeriodicity?.semanticMatchRate ?? 0
    let signatureRatio =
      report.eventSignatureRecurrence.observationCount == 0
      ? 0
      : Double(report.eventSignatureRecurrence.repeatObservationCount)
        / Double(report.eventSignatureRecurrence.observationCount)
    let recallCount = report.identityRecall.identityReturnBarCount
    let recallRatio =
      recallCount == 0
      ? 1
      : Double(report.identityRecall.matchedHomeSignatureBarCount)
        / Double(recallCount)
    let debtPaid = report.dramaticDebt.paidCount
    let zeroAgeRatio =
      debtPaid == 0
      ? 0 : Double(report.dramaticDebt.zeroAgePaidCount) / Double(debtPaid)
    let maximumCapabilityRun =
      report.capabilityRecurrence
      .map(\.maximumRunBars).max() ?? 0
    let values: [LongHorizonPolicyNamedValue] = [
      .init(metric: .highTensionDwellBars, value: Double(report.tensionDwell.maximumHighDwellBars)),
      .init(
        metric: .recoveryBarRatio,
        value: Double(report.tensionDwell.recoveryBarCount)
          / Double(report.observedBarCount)),
      .init(metric: .dominantSemanticPeriodicity, value: periodicity),
      .init(metric: .eventSignatureRepeatRatio, value: signatureRatio),
      .init(metric: .matchedIdentityRecallRatio, value: recallRatio),
      .init(metric: .zeroAgeDebtRatio, value: zeroAgeRatio),
      .init(
        metric: .overdueDebtCount,
        value: Double(
          report.dramaticDebt.overduePaidCount
            + report.dramaticDebt.overdueOutstandingCount)),
      .init(
        metric: .oldestDebtAgeBars,
        value: Double(report.dramaticDebt.oldestOutstandingAgeBars)),
      .init(metric: .maximumCapabilityRunBars, value: Double(maximumCapabilityRun)),
    ]
    guard values.map(\.metric) == LongHorizonPolicySemanticMetric.allCases,
      values.allSatisfy({ $0.value.isFinite && $0.value >= 0 })
    else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
    return values
  }

}

package struct LongHorizonPolicyCalibrationCorpus: Codable, Equatable,
  Sendable
{
  package let schemaVersion: String
  package let engineVersion: String
  package let primaryPolicyVersion: String
  package let observations: [LongHorizonPolicyObservation]
  package let fingerprint: String

  package init(observations: [LongHorizonPolicyObservation]) throws {
    let sorted = observations.sorted { $0.rootSeed < $1.rootSeed }
    guard sorted.count >= LongHorizonProfessionalPolicySchema.minimumHoldoutJourneyCount,
      sorted.allSatisfy(\.isComplete),
      Set(sorted.map(\.rootSeed)).count == sorted.count,
      Set(sorted.map(\.sourceFingerprint)).count == sorted.count,
      Set(sorted.map(\.engineVersion)).count == 1,
      Set(sorted.map(\.primaryPolicyVersion)).count == 1,
      Set(sorted.map(\.sampleRates)).count == 1
    else {
      throw LongHorizonProfessionalPolicyError.insufficientEvidence
    }
    schemaVersion = LongHorizonProfessionalPolicySchema.corpusVersion
    engineVersion = sorted[0].engineVersion
    primaryPolicyVersion = sorted[0].primaryPolicyVersion
    self.observations = sorted
    fingerprint = Self.makeFingerprint(sorted)
  }

  package var isComplete: Bool {
    schemaVersion == LongHorizonProfessionalPolicySchema.corpusVersion
      && engineVersion == QualityQualificationContract.engineVersion
      && observations.allSatisfy(\.isComplete)
      && observations == observations.sorted { $0.rootSeed < $1.rootSeed }
      && Set(observations.map(\.rootSeed)).count == observations.count
      && Set(observations.map(\.sourceFingerprint)).count == observations.count
      && observations.allSatisfy {
        $0.engineVersion == engineVersion
          && $0.primaryPolicyVersion == primaryPolicyVersion
      }
      && fingerprint == Self.makeFingerprint(observations)
  }

  package func deterministicJSON() throws -> Data {
    try LongHorizonPolicyJSON.encode(self)
  }

  package static func decodeDeterministicJSON(_ data: Data) throws -> Self {
    let decoded = try JSONDecoder().decode(Self.self, from: data)
    guard decoded.isComplete,
      try decoded.deterministicJSON() == data
    else { throw LongHorizonProfessionalPolicyError.nonCanonicalJSON }
    return decoded
  }

  fileprivate static func makeFingerprint(
    _ observations: [LongHorizonPolicyObservation]
  ) -> String {
    var hasher = LongHorizonPolicyHasher()
    hasher.mix(LongHorizonProfessionalPolicySchema.corpusVersion)
    for observation in observations {
      hasher.mix(observation.sourceFingerprint)
    }
    return hasher.hex
  }
}

/// Versioned non-compensable bounds learned from diverse exact-engine
/// development journeys. Semantic, signal, and effect dimensions remain
/// individually addressable and are never averaged.
package struct LongHorizonProfessionalProfile: Codable, Equatable, Sendable {
  package let profileVersion: String
  package let engineVersion: String
  package let primaryPolicyVersion: String
  package let developmentCorpusFingerprint: String
  package let developmentJourneyCount: Int
  package let developmentRootSeeds: [UInt64]
  package let sampleRates: [Double]
  package let semanticBounds: [LongHorizonPolicySemanticBound]
  package let operatorDeltaBounds: [LongHorizonPolicyOperatorDeltaBound]
  package let effectBounds: [LongHorizonPolicyEffectBound]
  package let fingerprint: String

  package init(corpus: LongHorizonPolicyCalibrationCorpus) throws {
    guard corpus.isComplete,
      corpus.observations.count
        >= LongHorizonProfessionalPolicySchema.minimumDevelopmentJourneyCount,
      corpus.observations.allSatisfy({
        $0.routes.allSatisfy { $0.observedBarCount
          >= LongHorizonProfessionalPolicySchema.minimumJourneyBars }
      })
    else {
      throw LongHorizonProfessionalPolicyError.insufficientEvidence
    }
    let semanticBounds = try LongHorizonPolicySemanticMetric.allCases.map { metric in
      let values = try corpus.observations.flatMap(\.routes).map { observation in
        guard let value = observation.semanticValues.first(where: { $0.metric == metric })?.value else {
          throw LongHorizonProfessionalPolicyError.invalidEvidence
        }
        return value
      }
      return LongHorizonPolicySemanticBound(
        metric: metric,
        bounds: try Self.expandedBounds(
          values,
          metric: metric))
    }
    let sampleRates = corpus.observations[0].sampleRates
    let operatorBounds = try sampleRates.flatMap { sampleRate in
      try LongHorizonEpisodeOperator.allCases.flatMap { operatorKind in
        try LongHorizonSignalMetric.allCases.map { metric in
          let values = try corpus.observations.map { observation in
            guard
              let value = observation.operatorDeltas.first(where: {
                $0.sampleRate == sampleRate && $0.operatorKind == operatorKind
                  && $0.metric == metric
              })?.meanDelta
            else {
              throw LongHorizonProfessionalPolicyError.invalidEvidence
            }
            return value
          }
          return LongHorizonPolicyOperatorDeltaBound(
            sampleRate: sampleRate,
            operatorKind: operatorKind,
            metric: metric,
            bounds: try Self.expandedSignalBounds(values, metric: metric))
        }
      }
    }
    let effectBounds = try LongHorizonEffectFamily.allCases.map { family in
      let values = try corpus.observations.flatMap(\.routes).map {
        observation -> LongHorizonPolicyEffectObservation in
        guard let effect = observation.effects.first(where: { $0.family == family })
        else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
        return effect
      }
      let wetUpper = min(1, (values.map(\.wetBarOccupancy).max() ?? 0) + 0.12)
      let tailUpper = min(
        1,
        (values.map {
          Double($0.tailOnlyBarCount) / Double($0.observedBarCount)
        }.max() ?? 0) + 0.08)
      let runUpper = (values.map(\.maximumActiveRunBars).max() ?? 0) + 4
      let returnUpper = values.compactMap(\.maximumReturnToSourceDB).max().map { $0 + 6 }
      let minimumMaterialWorldCount = family == .generatedGraph
        ? max(1, (values.compactMap(\.materialWorldCount).min() ?? 1) - 1)
        : nil
      let maximumMeanEffectWorldDistance = family == .generatedGraph
        ? min(
          1,
          (values.compactMap(\.meanEffectWorldDistance).max() ?? 1) + 0.05
        ) : nil
      let maximumEffectWorldDistance = family == .generatedGraph
        ? min(
          1,
          (values.compactMap(\.maximumEffectWorldDistance).max() ?? 1) + 0.08
        ) : nil
      return LongHorizonPolicyEffectBound(
        family: family,
        maximumWetBarOccupancy: wetUpper,
        maximumTailBarOccupancy: tailUpper,
        maximumActiveRunBars: runUpper,
        maximumReturnToSourceDB: returnUpper,
        minimumMaterialWorldCount: minimumMaterialWorldCount,
        maximumMeanEffectWorldDistance: maximumMeanEffectWorldDistance,
        maximumEffectWorldDistance: maximumEffectWorldDistance)
    }
    profileVersion = LongHorizonProfessionalPolicySchema.profileVersion
    engineVersion = corpus.engineVersion
    primaryPolicyVersion = corpus.primaryPolicyVersion
    developmentCorpusFingerprint = corpus.fingerprint
    developmentJourneyCount = corpus.observations.count
    developmentRootSeeds = corpus.observations.map(\.rootSeed)
    self.sampleRates = sampleRates
    self.semanticBounds = semanticBounds
    operatorDeltaBounds = operatorBounds
    self.effectBounds = effectBounds
    fingerprint = Self.makeFingerprint(
      corpusFingerprint: corpus.fingerprint,
      primaryPolicyVersion: corpus.primaryPolicyVersion,
      semanticBounds: semanticBounds,
      operatorBounds: operatorBounds,
      effectBounds: effectBounds)
  }

  package var isComplete: Bool {
    profileVersion == LongHorizonProfessionalPolicySchema.profileVersion
      && engineVersion == QualityQualificationContract.engineVersion
      && primaryPolicyVersion
        == LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion
      && developmentJourneyCount
        >= LongHorizonProfessionalPolicySchema.minimumDevelopmentJourneyCount
      && developmentRootSeeds.count == developmentJourneyCount
      && Set(developmentRootSeeds).count == developmentRootSeeds.count
      && sampleRates.count
        >= LongHorizonProfessionalPolicySchema.minimumSignalRateCount
      && semanticBounds.map(\.metric)
        == LongHorizonPolicySemanticMetric.allCases
      && operatorDeltaBounds.count
        == sampleRates.count * LongHorizonEpisodeOperator.allCases.count
        * LongHorizonSignalMetric.allCases.count
      && effectBounds.map(\.family) == LongHorizonEffectFamily.allCases
      && effectBounds.allSatisfy { bound in
        if bound.family == .generatedGraph {
          return (bound.minimumMaterialWorldCount ?? 0) > 0
            && (bound.maximumMeanEffectWorldDistance.map {
              $0.isFinite && (0...1).contains($0)
            } ?? false)
            && (bound.maximumEffectWorldDistance.map {
              $0.isFinite && (0...1).contains($0)
            } ?? false)
        }
        return bound.minimumMaterialWorldCount == nil
          && bound.maximumMeanEffectWorldDistance == nil
          && bound.maximumEffectWorldDistance == nil
      }
      && fingerprint
        == Self.makeFingerprint(
          corpusFingerprint: developmentCorpusFingerprint,
          primaryPolicyVersion: primaryPolicyVersion,
          semanticBounds: semanticBounds,
          operatorBounds: operatorDeltaBounds,
          effectBounds: effectBounds)
  }

  package func semanticBound(
    _ metric: LongHorizonPolicySemanticMetric
  ) -> LongHorizonPolicyBounds? {
    semanticBounds.first { $0.metric == metric }?.bounds
  }

  package func deterministicJSON() throws -> Data {
    try LongHorizonPolicyJSON.encode(self)
  }

  package static func decodeDeterministicJSON(_ data: Data) throws -> Self {
    let decoded = try JSONDecoder().decode(Self.self, from: data)
    guard decoded.isComplete,
      try decoded.deterministicJSON() == data
    else { throw LongHorizonProfessionalPolicyError.nonCanonicalJSON }
    return decoded
  }

  private static func expandedBounds(
    _ values: [Double],
    metric: LongHorizonPolicySemanticMetric
  ) throws -> LongHorizonPolicyBounds {
    guard let minimum = values.min(), let maximum = values.max(),
      minimum.isFinite, maximum.isFinite
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let span = maximum - minimum
    let padding: Double
    switch metric {
    case .recoveryBarRatio, .matchedIdentityRecallRatio:
      padding = max(0.02, span * 0.25)
      return try LongHorizonPolicyBounds(
        lower: max(0, minimum - padding),
        upper: 1)
    case .dominantSemanticPeriodicity, .eventSignatureRepeatRatio,
      .zeroAgeDebtRatio:
      padding = max(0.02, span * 0.25)
      return try LongHorizonPolicyBounds(
        lower: 0,
        upper: min(1, maximum + padding))
    case .overdueDebtCount:
      padding = max(1, span * 0.25)
      return try LongHorizonPolicyBounds(lower: 0, upper: maximum + padding)
    case .highTensionDwellBars, .oldestDebtAgeBars,
      .maximumCapabilityRunBars:
      padding = max(2, span * 0.35)
      return try LongHorizonPolicyBounds(lower: 0, upper: maximum + padding)
    }
  }

  private static func expandedSignalBounds(
    _ values: [Double],
    metric: LongHorizonSignalMetric
  ) throws -> LongHorizonPolicyBounds {
    guard let minimum = values.min(), let maximum = values.max(),
      minimum.isFinite, maximum.isFinite
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let floor: Double
    switch metric {
    // These floors represent uncertainty in a sparse two-to-five-transition
    // operator mean, not an absolute sound-quality target. Spectral centroid
    // retains the observed cross-operator predecessor-context spread, while
    // the dB floors cover finite-sample and route-rounded summary variation.
    // Every contributing phrase has already passed the primary professional
    // evaluator independently.
    case .spectralCentroidHz: floor = 2_500
    case .spectralCentroidSpreadHz: floor = 5_000
    case .meanBarCrestFactorDB:
      floor = 1.67
    case .integratedLoudnessLUFS, .maximumMomentaryLoudnessLUFS,
      .truePeakDBTP:
      floor = 1.65
    case .meanWetToDryDB: floor = 18
    case .transientDensityPerSecond: floor = 0.55
    case .movementScore: floor = 0.15
    default: floor = 0.08
    }
    let padding = max(floor, (maximum - minimum) * 0.35)
    return try LongHorizonPolicyBounds(
      lower: minimum - padding, upper: maximum + padding)
  }

  private static func makeFingerprint(
    corpusFingerprint: String,
    primaryPolicyVersion: String,
    semanticBounds: [LongHorizonPolicySemanticBound],
    operatorBounds: [LongHorizonPolicyOperatorDeltaBound],
    effectBounds: [LongHorizonPolicyEffectBound]
  ) -> String {
    var hasher = LongHorizonPolicyHasher()
    hasher.mix(LongHorizonProfessionalPolicySchema.profileVersion)
    hasher.mix(corpusFingerprint)
    hasher.mix(primaryPolicyVersion)
    for bound in semanticBounds {
      hasher.mix(bound.metric.rawValue)
      hasher.mix(bound.bounds.lower)
      hasher.mix(bound.bounds.upper)
    }
    for bound in operatorBounds {
      hasher.mix(bound.sampleRate)
      hasher.mix(bound.operatorKind.rawValue)
      hasher.mix(bound.metric.rawValue)
      hasher.mix(bound.bounds.lower)
      hasher.mix(bound.bounds.upper)
    }
    for bound in effectBounds {
      hasher.mix(bound.family.rawValue)
      hasher.mix(bound.maximumWetBarOccupancy)
      hasher.mix(bound.maximumTailBarOccupancy)
      hasher.mix(bound.maximumActiveRunBars)
      hasher.mix(
        bound.maximumReturnToSourceDB ?? -Double.greatestFiniteMagnitude)
      hasher.mix(bound.minimumMaterialWorldCount ?? -1)
      hasher.mix(
        bound.maximumMeanEffectWorldDistance ??
          -Double.greatestFiniteMagnitude)
      hasher.mix(
        bound.maximumEffectWorldDistance ??
          -Double.greatestFiniteMagnitude)
    }
    return hasher.hex
  }
}

package enum LongHorizonPolicyFailureDimension: String, CaseIterable,
  Codable, Sendable
{
  case identity
  case duration
  case semanticPeriodicity = "semantic-periodicity"
  case permanentPeak = "permanent-peak"
  case recoveryStarvation = "recovery-starvation"
  case identityRecall = "identity-recall"
  case dramaticDebt = "dramatic-debt"
  case capabilityFatigue = "capability-fatigue"
  case operatorConsequence = "operator-consequence"
  case effectFatigue = "effect-fatigue"
}

package struct LongHorizonPolicyVerdict: Codable, Equatable, Sendable,
  AutonomousEvidenceCategorizedReport
{
  package static let evidenceCategory: AutonomousEvidenceCategory = .calibratedQuality
  package let accepted: Bool
  package let failedDimensions: [LongHorizonPolicyFailureDimension]
  package let failedSemanticMetrics: [LongHorizonPolicySemanticMetric]
  package let failedOperatorDeltas: [LongHorizonPolicyOperatorDelta]
  package let failedEffectFamilies: [LongHorizonEffectFamily]
  package var routeVerdicts: [LongHorizonPolicyRouteVerdict] = []

  package var allNativeRoutesAccepted: Bool {
    accepted && failedDimensions.isEmpty && failedSemanticMetrics.isEmpty
      && failedOperatorDeltas.isEmpty && failedEffectFamilies.isEmpty
      && routeVerdicts.map(\.sampleRate) == [44_100, 48_000]
      && routeVerdicts.allSatisfy {
        $0.sourceFingerprint.count == 16 && $0.verdict.accepted
          && $0.verdict.failedDimensions.isEmpty && $0.verdict.failedSemanticMetrics.isEmpty
          && $0.verdict.failedOperatorDeltas.isEmpty && $0.verdict.failedEffectFamilies.isEmpty
          && $0.verdict.routeVerdicts.isEmpty
      }
  }
}

package struct LongHorizonPolicyRouteVerdict: Codable, Equatable, Sendable {
  package let sampleRate: Double
  package let sourceFingerprint: String
  package let verdict: LongHorizonPolicyVerdict
}

/// Pure detached judge. It can reject evidence or ask the future controller to
/// retain the current episode, but it cannot mutate a plan or scheduled PCM.
package struct LongHorizonProfessionalProfileEvaluator: Sendable {
  package let profile: LongHorizonProfessionalProfile

  package init(profile: LongHorizonProfessionalProfile) throws {
    guard profile.isComplete else {
      throw LongHorizonProfessionalPolicyError.profileMismatch
    }
    self.profile = profile
  }

  package func evaluate(
    _ observation: LongHorizonPolicyObservation,
    expectedRootSeed: UInt64? = nil
  ) -> LongHorizonPolicyVerdict {
    guard observation.isComplete, observation.sampleRates == profile.sampleRates,
      expectedRootSeed.map({ $0 == observation.rootSeed }) ?? true
    else {
      return LongHorizonPolicyVerdict(accepted: false, failedDimensions: [.identity],
        failedSemanticMetrics: [], failedOperatorDeltas: [], failedEffectFamilies: [])
    }
    let routes = observation.routes.map { route in
      LongHorizonPolicyRouteVerdict(sampleRate: route.sampleRate,
        sourceFingerprint: route.sourceFingerprint,
        verdict: evaluate(route, expectedRootSeed: observation.rootSeed))
    }
    let verdicts = routes.map(\.verdict)
    return LongHorizonPolicyVerdict(accepted: verdicts.allSatisfy(\.accepted),
      failedDimensions: LongHorizonPolicyFailureDimension.allCases.filter {
        Set(verdicts.flatMap(\.failedDimensions)).contains($0)
      },
      failedSemanticMetrics: LongHorizonPolicySemanticMetric.allCases.filter {
        Set(verdicts.flatMap(\.failedSemanticMetrics)).contains($0)
      },
      failedOperatorDeltas: verdicts.flatMap(\.failedOperatorDeltas),
      failedEffectFamilies: LongHorizonEffectFamily.allCases.filter {
        Set(verdicts.flatMap(\.failedEffectFamilies)).contains($0)
      }, routeVerdicts: routes)
  }
}

package enum LongHorizonAdversarialAttack: String, CaseIterable, Codable,
  Sendable
{
  case permanentPeak = "permanent-peak"
  case fixedSawtooth = "fixed-sawtooth"
  case strictAlternation = "strict-alternation"
  case failedRecall = "failed-recall"
  case periodicRareGesture = "periodic-rare-gesture"
  case effectWetnessRatchet = "effect-wetness-ratchet"
  case monotonicDecline = "monotonic-decline"
  case instantDebtPayment = "instant-debt-payment"
  case semanticSignalMismatch = "semantic-signal-mismatch"
  case routeIdentityReset = "route-identity-reset"
}

package struct LongHorizonAdversarialCaseVerdict: Codable, Equatable,
  Sendable, AutonomousEvidenceCategorizedReport
{
  package static let evidenceCategory: AutonomousEvidenceCategory = .provenance
  package let attack: LongHorizonAdversarialAttack
  package let sampleRate: Double
  package let rejected: Bool
  package let failedDimensions: [LongHorizonPolicyFailureDimension]
}

package struct LongHorizonAdversarialSuiteReport: Codable, Equatable,
  Sendable, AutonomousEvidenceCategorizedReport
{
  package static let evidenceCategory: AutonomousEvidenceCategory = .provenance
  package let schemaVersion: String
  package let engineVersion: String
  package let profileFingerprint: String
  package let sourceObservationFingerprint: String
  package let cases: [LongHorizonAdversarialCaseVerdict]
  package let passed: Bool
  package let fingerprint: String

  package init(
    profile: LongHorizonProfessionalProfile,
    sourceObservation: LongHorizonPolicyObservation
  ) throws {
    let evaluator = try LongHorizonProfessionalProfileEvaluator(profile: profile)
    guard evaluator.evaluate(sourceObservation).accepted else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
    let cases = sourceObservation.sampleRates.flatMap { rate in
      LongHorizonAdversarialAttack.allCases.map { attack in
      let attacked = LongHorizonPolicyObservation(uncheckedRoutes: sourceObservation.routes.map {
        $0.sampleRate == rate ? $0.attacked(by: attack, profile: profile) : $0
      })
      let verdict: LongHorizonPolicyVerdict
      if attack == .routeIdentityReset {
        verdict = evaluator.evaluate(
          attacked, expectedRootSeed: sourceObservation.rootSeed)
      } else {
        verdict = evaluator.evaluate(attacked)
      }
      return LongHorizonAdversarialCaseVerdict(
        attack: attack, sampleRate: rate,
        rejected: !verdict.accepted,
        failedDimensions: verdict.failedDimensions)
      }
    }
    schemaVersion = LongHorizonProfessionalPolicySchema.adversarialVersion
    engineVersion = profile.engineVersion
    profileFingerprint = profile.fingerprint
    sourceObservationFingerprint = sourceObservation.sourceFingerprint
    self.cases = cases
    passed =
      cases.count == 2 * LongHorizonAdversarialAttack.allCases.count
      && cases.allSatisfy { $0.rejected && !$0.failedDimensions.isEmpty }
    fingerprint = Self.makeFingerprint(
      profileFingerprint: profile.fingerprint,
      sourceFingerprint: sourceObservation.sourceFingerprint,
      cases: cases)
    guard passed else {
      throw LongHorizonProfessionalPolicyError.adversarialFailure
    }
  }

  package var isComplete: Bool {
    schemaVersion == LongHorizonProfessionalPolicySchema.adversarialVersion
      && engineVersion == QualityQualificationContract.engineVersion
      && cases.map(\.attack) == [44_100, 48_000].flatMap { _ in LongHorizonAdversarialAttack.allCases }
      && cases.map(\.sampleRate) == [44_100.0, 48_000.0].flatMap { rate in
        LongHorizonAdversarialAttack.allCases.map { _ in rate }
      }
      && passed && cases.allSatisfy { $0.rejected && !$0.failedDimensions.isEmpty }
      && fingerprint
        == Self.makeFingerprint(
          profileFingerprint: profileFingerprint,
          sourceFingerprint: sourceObservationFingerprint,
          cases: cases)
  }

  package func deterministicJSON() throws -> Data {
    try LongHorizonPolicyJSON.encode(self)
  }

  package static func decodeDeterministicJSON(_ data: Data) throws -> Self {
    let decoded = try JSONDecoder().decode(Self.self, from: data)
    guard decoded.isComplete,
      try decoded.deterministicJSON() == data
    else { throw LongHorizonProfessionalPolicyError.nonCanonicalJSON }
    return decoded
  }

  private static func makeFingerprint(
    profileFingerprint: String,
    sourceFingerprint: String,
    cases: [LongHorizonAdversarialCaseVerdict]
  ) -> String {
    var hasher = LongHorizonPolicyHasher()
    hasher.mix(LongHorizonProfessionalPolicySchema.adversarialVersion)
    hasher.mix(profileFingerprint)
    hasher.mix(sourceFingerprint)
    for adversarialCase in cases {
      hasher.mix(adversarialCase.attack.rawValue)
      hasher.mix(adversarialCase.sampleRate)
      hasher.mix(adversarialCase.rejected ? 1 : 0)
      for dimension in adversarialCase.failedDimensions {
        hasher.mix(dimension.rawValue)
      }
    }
    return hasher.hex
  }
}

package struct LongHorizonHoldoutJourneyVerdict: Codable, Equatable,
  Sendable, AutonomousEvidenceCategorizedReport
{
  package static let evidenceCategory: AutonomousEvidenceCategory = .provenance
  package let rootSeed: UInt64
  package let sourceFingerprint: String
  package let verdict: LongHorizonPolicyVerdict
}

package struct LongHorizonHoldoutQualification: Codable, Equatable, Sendable,
  AutonomousEvidenceCategorizedReport
{
  package static let evidenceCategory: AutonomousEvidenceCategory = .provenance
  package let schemaVersion: String
  package let engineVersion: String
  package let profileFingerprint: String
  package let adversarialFingerprint: String
  package let developmentCorpusFingerprint: String
  package let holdoutCorpusFingerprint: String
  package let journeys: [LongHorizonHoldoutJourneyVerdict]
  package let qualified: Bool
  package let fingerprint: String

  package init(
    profile: LongHorizonProfessionalProfile,
    adversarial: LongHorizonAdversarialSuiteReport,
    developmentCorpus: LongHorizonPolicyCalibrationCorpus,
    holdoutCorpus: LongHorizonPolicyCalibrationCorpus
  ) throws {
    guard profile.isComplete, adversarial.isComplete, adversarial.passed,
      adversarial.profileFingerprint == profile.fingerprint,
      developmentCorpus.isComplete,
      developmentCorpus.fingerprint == profile.developmentCorpusFingerprint,
      holdoutCorpus.isComplete,
      holdoutCorpus.observations.count
        >= LongHorizonProfessionalPolicySchema.minimumHoldoutJourneyCount,
      Set(developmentCorpus.observations.map(\.rootSeed)).isDisjoint(
        with: Set(holdoutCorpus.observations.map(\.rootSeed))),
      Set(developmentCorpus.observations.map(\.sourceFingerprint)).isDisjoint(
        with: Set(holdoutCorpus.observations.map(\.sourceFingerprint)))
    else {
      throw LongHorizonProfessionalPolicyError.holdoutFailure
    }
    let evaluator = try LongHorizonProfessionalProfileEvaluator(profile: profile)
    let journeys = holdoutCorpus.observations.map { observation in
      LongHorizonHoldoutJourneyVerdict(
        rootSeed: observation.rootSeed,
        sourceFingerprint: observation.sourceFingerprint,
        verdict: evaluator.evaluate(observation))
    }
    schemaVersion = LongHorizonProfessionalPolicySchema.holdoutVersion
    engineVersion = profile.engineVersion
    profileFingerprint = profile.fingerprint
    adversarialFingerprint = adversarial.fingerprint
    developmentCorpusFingerprint = developmentCorpus.fingerprint
    holdoutCorpusFingerprint = holdoutCorpus.fingerprint
    self.journeys = journeys
    qualified =
      journeys.count
      >= LongHorizonProfessionalPolicySchema.minimumHoldoutJourneyCount
      && journeys.allSatisfy { $0.verdict.allNativeRoutesAccepted }
    fingerprint = Self.makeFingerprint(
      profileFingerprint: profile.fingerprint,
      adversarialFingerprint: adversarial.fingerprint,
      developmentFingerprint: developmentCorpus.fingerprint,
      holdoutFingerprint: holdoutCorpus.fingerprint,
      journeys: journeys)
  }

  package var isComplete: Bool {
    schemaVersion == LongHorizonProfessionalPolicySchema.holdoutVersion
      && engineVersion == QualityQualificationContract.engineVersion
      && journeys.count
        >= LongHorizonProfessionalPolicySchema.minimumHoldoutJourneyCount
      && qualified && journeys.allSatisfy { $0.verdict.allNativeRoutesAccepted }
      && fingerprint
        == Self.makeFingerprint(
          profileFingerprint: profileFingerprint,
          adversarialFingerprint: adversarialFingerprint,
          developmentFingerprint: developmentCorpusFingerprint,
          holdoutFingerprint: holdoutCorpusFingerprint,
          journeys: journeys)
  }

  package func deterministicJSON() throws -> Data {
    try LongHorizonPolicyJSON.encode(self)
  }

  package static func decodeDeterministicJSON(_ data: Data) throws -> Self {
    let decoded = try JSONDecoder().decode(Self.self, from: data)
    guard decoded.isComplete,
      try decoded.deterministicJSON() == data
    else { throw LongHorizonProfessionalPolicyError.nonCanonicalJSON }
    return decoded
  }

  private static func makeFingerprint(
    profileFingerprint: String,
    adversarialFingerprint: String,
    developmentFingerprint: String,
    holdoutFingerprint: String,
    journeys: [LongHorizonHoldoutJourneyVerdict]
  ) -> String {
    var hasher = LongHorizonPolicyHasher()
    hasher.mix(LongHorizonProfessionalPolicySchema.holdoutVersion)
    hasher.mix(profileFingerprint)
    hasher.mix(adversarialFingerprint)
    hasher.mix(developmentFingerprint)
    hasher.mix(holdoutFingerprint)
    for journey in journeys {
      hasher.mix(journey.rootSeed)
      hasher.mix(journey.sourceFingerprint)
      hasher.mix(journey.verdict.accepted ? 1 : 0)
      for route in journey.verdict.routeVerdicts {
        hasher.mix(route.sampleRate); hasher.mix(route.sourceFingerprint)
        hasher.mix(route.verdict.accepted ? 1 : 0)
      }
    }
    return hasher.hex
  }
}

/// Construction is possible only from one exact development profile, a passed
/// adversarial suite, and a disjoint accepted holdout. The resulting decision
/// remains detached and reason-coded for Stage 7 to consume at a future phrase
/// boundary.
package struct LongHorizonProfessionalPolicy: Sendable {
  package let profile: LongHorizonProfessionalProfile
  package let adversarial: LongHorizonAdversarialSuiteReport
  package let holdout: LongHorizonHoldoutQualification
  package let policyVersion: String

  package init(
    profile: LongHorizonProfessionalProfile,
    adversarial: LongHorizonAdversarialSuiteReport,
    holdout: LongHorizonHoldoutQualification
  ) throws {
    guard profile.isComplete, adversarial.isComplete, holdout.isComplete,
      adversarial.profileFingerprint == profile.fingerprint,
      holdout.profileFingerprint == profile.fingerprint,
      holdout.adversarialFingerprint == adversarial.fingerprint,
      holdout.developmentCorpusFingerprint
        == profile.developmentCorpusFingerprint
    else { throw LongHorizonProfessionalPolicyError.profileMismatch }
    self.profile = profile
    self.adversarial = adversarial
    self.holdout = holdout
    policyVersion = [
      LongHorizonProfessionalPolicySchema.policyFamilyVersion,
      "profile-\(profile.fingerprint)",
      "adversarial-\(adversarial.fingerprint)",
      "holdout-\(holdout.fingerprint)",
    ].joined(separator: ".")
  }

  package func evaluate(
    _ observation: LongHorizonPolicyObservation,
    expectedRootSeed: UInt64? = nil
  ) -> LongHorizonPolicyVerdict {
    guard
      let evaluator = try? LongHorizonProfessionalProfileEvaluator(
        profile: profile)
    else {
      return LongHorizonPolicyVerdict(
        accepted: false,
        failedDimensions: [.identity],
        failedSemanticMetrics: [],
        failedOperatorDeltas: [],
        failedEffectFamilies: [])
    }
    return evaluator.evaluate(observation, expectedRootSeed: expectedRootSeed)
  }
}

extension LongHorizonRuntimePolicyObservation {
  fileprivate func attacked(
    by attack: LongHorizonAdversarialAttack,
    profile: LongHorizonProfessionalProfile
  ) -> Self {
    var semantic = semanticValues
    var deltas = operatorDeltas
    var effects = self.effects
    var rootSeed = self.rootSeed
    func exceed(_ metric: LongHorizonPolicySemanticMetric, upper: Bool) {
      guard let index = semantic.firstIndex(where: { $0.metric == metric }),
        let bounds = profile.semanticBound(metric)
      else { return }
      semantic[index] = LongHorizonPolicyNamedValue(
        metric: metric,
        value: upper ? bounds.upper + max(1, abs(bounds.upper) * 0.5) : bounds.lower - 1)
    }
    switch attack {
    case .permanentPeak:
      exceed(.highTensionDwellBars, upper: true)
    case .fixedSawtooth, .strictAlternation:
      exceed(.dominantSemanticPeriodicity, upper: true)
    case .failedRecall:
      exceed(.matchedIdentityRecallRatio, upper: false)
    case .periodicRareGesture:
      exceed(.maximumCapabilityRunBars, upper: true)
    case .effectWetnessRatchet:
      if let index = effects.indices.first,
        let bound = profile.effectBounds.first(where: {
          $0.family == effects[index].family
        })
      {
        let original = effects[index]
        effects[index] = LongHorizonPolicyEffectObservation(
          family: original.family,
          observedBarCount: original.observedBarCount,
          eligibleBarCount: original.eligibleBarCount,
          activeBarCount: original.observedBarCount,
          tailOnlyBarCount: original.tailOnlyBarCount,
          recoveryCount: 0,
          maximumActiveRunBars: bound.maximumActiveRunBars + 8,
          wetBarOccupancy: min(1, bound.maximumWetBarOccupancy + 0.2),
          maximumReturnToSourceDB: bound.maximumReturnToSourceDB.map { $0 + 6 },
          materialWorldCount: original.materialWorldCount,
          meanEffectWorldDistance: original.meanEffectWorldDistance,
          maximumEffectWorldDistance: original.maximumEffectWorldDistance)
      }
    case .monotonicDecline, .semanticSignalMismatch:
      if let index = deltas.firstIndex(where: { delta in
        delta.operatorKind == .rise
          && delta.metric == .integratedLoudnessLUFS
      }),
        let bound = profile.operatorDeltaBounds.first(where: {
          $0.sampleRate == deltas[index].sampleRate
            && $0.operatorKind == deltas[index].operatorKind
            && $0.metric == deltas[index].metric
        })
      {
        let original = deltas[index]
        deltas[index] = LongHorizonPolicyOperatorDelta(
          sampleRate: original.sampleRate,
          operatorKind: original.operatorKind,
          metric: original.metric,
          transitionCount: original.transitionCount,
          meanDelta: bound.bounds.lower - max(2, abs(bound.bounds.lower)))
      }
    case .instantDebtPayment:
      exceed(.zeroAgeDebtRatio, upper: true)
    case .routeIdentityReset:
      rootSeed &+= 1
    }
    return LongHorizonRuntimePolicyObservation(
      engineVersion: engineVersion, primaryPolicyVersion: primaryPolicyVersion,
      rootSeed: rootSeed, semanticFingerprint: semanticFingerprint,
      observedPhraseCount: observedPhraseCount, observedBarCount: observedBarCount,
      semanticValues: semantic, sampleRate: sampleRate,
      signalFingerprint: signalFingerprint, signalObservationCount: signalObservationCount,
      signalOmittedPhraseCount: signalOmittedPhraseCount,
      operatorDeltas: deltas, effects: effects)
  }
}

private struct LongHorizonPolicyHasher: Sendable {
  private var value: UInt64 = 0xcbf2_9ce4_8422_2325

  mutating func mix(_ text: String) {
    for byte in text.utf8 {
      value ^= UInt64(byte)
      value &*= 0x0000_0100_0000_01b3
    }
    value ^= 0xff
    value &*= 0x0000_0100_0000_01b3
  }

  mutating func mix(_ integer: Int) { mix(String(integer)) }
  mutating func mix(_ integer: UInt64) { mix(String(integer)) }
  mutating func mix(_ value: Double) { mix(String(value.bitPattern)) }

  var hex: String {
    let raw = String(value, radix: 16)
    return String(repeating: "0", count: max(0, 16 - raw.count)) + raw
  }
}

private enum LongHorizonPolicyJSON {
  static func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }
}
