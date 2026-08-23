import AutoTechnoCore
import Foundation

/// Reduced evidence accepted by the calibrated professional policy while the
/// one canonical performance is running. Calibration remains multi-rate; a
/// runtime verdict uses only the exact current route rate.
package enum LongHorizonRuntimePolicySchema {
  package static let observationVersion =
    "autotechno-long-horizon-runtime-observation.v1"
  package static let adaptationVersion =
    "autotechno-long-horizon-future-adaptation.v1"
  package static let minimumDecisionIntervalBars = 256
}

package struct LongHorizonRuntimePolicyObservation: Codable, Equatable,
  Sendable
{
  package let schemaVersion: String
  package let engineVersion: String
  package let primaryPolicyVersion: String
  package let rootSeed: UInt64
  package let semanticFingerprint: String
  package let observedPhraseCount: Int
  package let observedBarCount: Int
  package let semanticValues: [LongHorizonPolicyNamedValue]
  package let sampleRate: Double
  package let signalFingerprint: String
  package let signalObservationCount: Int
  package let signalOmittedPhraseCount: Int
  package let operatorDeltas: [LongHorizonPolicyOperatorDelta]
  package let effects: [LongHorizonPolicyEffectObservation]
  package let sourceFingerprint: String

  package init(
    semanticReport: LongHorizonSemanticTrajectoryReport,
    signalReport: LongHorizonSignalTrajectoryReport,
    effectReport: LongHorizonEffectDoseReport,
    primaryPolicyVersion: String
  ) throws {
    guard semanticReport.availability == .available,
      semanticReport.schemaVersion
        == LongHorizonSemanticTrajectorySchema.schemaVersion,
      semanticReport.schemaIdentifier
        == LongHorizonSemanticTrajectorySchema.schemaIdentifier,
      semanticReport.engineVersion == QualityQualificationContract.engineVersion,
      semanticReport.rootSeed == signalReport.rootSeed,
      semanticReport.rootSeed == effectReport.rootSeed,
      semanticReport.observedPhraseCount == effectReport.phraseCount,
      semanticReport.observedBarCount == effectReport.barCount,
      semanticReport.observedPhraseCount > 0,
      semanticReport.observedBarCount > 0,
      signalReport.availability == .available,
      signalReport.schemaVersion == LongHorizonSignalTrajectorySchema.schemaVersion,
      signalReport.schemaIdentifier
        == LongHorizonSignalTrajectorySchema.schemaIdentifier,
      signalReport.sampleRate.isFinite,
      signalReport.sampleRate > 0,
      signalReport.observationCount > 0,
      signalReport.operatorTransitions.count
        == LongHorizonEpisodeOperator.allCases.count,
      signalReport.operatorTransitions.allSatisfy({ transition in
        transition.transitionCount > 0
          && transition.metricDeltas.count == LongHorizonSignalMetric.allCases.count
      }),
      effectReport.availability == .available,
      effectReport.schemaVersion == LongHorizonEffectDoseSchema.schemaVersion,
      effectReport.schemaIdentifier == LongHorizonEffectDoseSchema.schemaIdentifier,
      effectReport.families.map(\.family) == LongHorizonEffectFamily.allCases,
      primaryPolicyVersion
        == LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion
    else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }

    let semanticValues = try LongHorizonPolicyObservation.semanticValues(
      from: semanticReport)
    let operatorDeltas = signalReport.operatorTransitions.flatMap { transition in
      transition.metricDeltas.map { summary in
        LongHorizonPolicyOperatorDelta(
          sampleRate: signalReport.sampleRate,
          operatorKind: transition.operatorKind,
          metric: summary.metric,
          transitionCount: summary.observationCount,
          meanDelta: summary.mean)
      }
    }
    let effects = effectReport.families.map { family in
      LongHorizonPolicyEffectObservation(
        family: family.family,
        observedBarCount: effectReport.barCount,
        eligibleBarCount: family.eligibleBarCount,
        activeBarCount: family.activeBarCount,
        tailOnlyBarCount: family.tailOnlyBarCount,
        recoveryCount: family.recoveryCount,
        maximumActiveRunBars: family.maximumActiveRunBars,
        wetBarOccupancy: family.wetBarOccupancy,
        maximumReturnToSourceDB: family.maximumReturnToSourceDB)
    }
    self.init(
      engineVersion: semanticReport.engineVersion,
      primaryPolicyVersion: primaryPolicyVersion,
      rootSeed: semanticReport.rootSeed,
      semanticFingerprint: semanticReport.trajectoryFingerprint,
      observedPhraseCount: semanticReport.observedPhraseCount,
      observedBarCount: semanticReport.observedBarCount,
      semanticValues: semanticValues,
      sampleRate: signalReport.sampleRate,
      signalFingerprint: signalReport.trajectoryFingerprint,
      signalObservationCount: signalReport.observationCount,
      signalOmittedPhraseCount: signalReport.omittedPhraseCount,
      operatorDeltas: operatorDeltas,
      effects: effects)
    guard isStructurallyComplete else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
  }

  package init(
    calibrationObservation: LongHorizonPolicyObservation,
    sampleRate: Double
  ) throws {
    guard calibrationObservation.isComplete,
      let rateIndex = calibrationObservation.sampleRates.firstIndex(of: sampleRate)
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    self.init(
      engineVersion: calibrationObservation.engineVersion,
      primaryPolicyVersion: calibrationObservation.primaryPolicyVersion,
      rootSeed: calibrationObservation.rootSeed,
      semanticFingerprint: calibrationObservation.semanticFingerprint,
      observedPhraseCount: calibrationObservation.observedPhraseCount,
      observedBarCount: calibrationObservation.observedBarCount,
      semanticValues: calibrationObservation.semanticValues,
      sampleRate: sampleRate,
      signalFingerprint: calibrationObservation.signalFingerprints[rateIndex],
      signalObservationCount:
        calibrationObservation.signalObservationCounts[rateIndex],
      signalOmittedPhraseCount:
        calibrationObservation.signalOmittedPhraseCounts[rateIndex],
      operatorDeltas: calibrationObservation.operatorDeltas.filter {
        $0.sampleRate == sampleRate
      },
      effects: calibrationObservation.effects)
    guard isStructurallyComplete else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
  }

  private init(
    engineVersion: String,
    primaryPolicyVersion: String,
    rootSeed: UInt64,
    semanticFingerprint: String,
    observedPhraseCount: Int,
    observedBarCount: Int,
    semanticValues: [LongHorizonPolicyNamedValue],
    sampleRate: Double,
    signalFingerprint: String,
    signalObservationCount: Int,
    signalOmittedPhraseCount: Int,
    operatorDeltas: [LongHorizonPolicyOperatorDelta],
    effects: [LongHorizonPolicyEffectObservation]
  ) {
    schemaVersion = LongHorizonRuntimePolicySchema.observationVersion
    self.engineVersion = engineVersion
    self.primaryPolicyVersion = primaryPolicyVersion
    self.rootSeed = rootSeed
    self.semanticFingerprint = semanticFingerprint
    self.observedPhraseCount = observedPhraseCount
    self.observedBarCount = observedBarCount
    self.semanticValues = semanticValues
    self.sampleRate = sampleRate
    self.signalFingerprint = signalFingerprint
    self.signalObservationCount = signalObservationCount
    self.signalOmittedPhraseCount = signalOmittedPhraseCount
    self.operatorDeltas = operatorDeltas
    self.effects = effects
    sourceFingerprint = Self.makeFingerprint(
      rootSeed: rootSeed,
      semanticFingerprint: semanticFingerprint,
      primaryPolicyVersion: primaryPolicyVersion,
      sampleRate: sampleRate,
      signalFingerprint: signalFingerprint,
      semanticValues: semanticValues,
      operatorDeltas: operatorDeltas,
      effects: effects)
  }

  package var isStructurallyComplete: Bool {
    schemaVersion == LongHorizonRuntimePolicySchema.observationVersion
      && engineVersion == QualityQualificationContract.engineVersion
      && primaryPolicyVersion
        == LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion
      && observedPhraseCount > 0 && observedBarCount > 0
      && semanticValues.map(\.metric)
        == LongHorizonPolicySemanticMetric.allCases
      && semanticValues.allSatisfy { $0.value.isFinite }
      && sampleRate.isFinite && sampleRate > 0
      && signalObservationCount > 0 && signalOmittedPhraseCount >= 0
      && operatorDeltas.count
        == LongHorizonEpisodeOperator.allCases.count
        * LongHorizonSignalMetric.allCases.count
      && operatorDeltas.allSatisfy {
        $0.sampleRate == sampleRate && $0.transitionCount > 0
          && $0.meanDelta.isFinite
      }
      && effects.map(\.family) == LongHorizonEffectFamily.allCases
      && effects.allSatisfy {
        $0.observedBarCount > 0
          && $0.eligibleBarCount >= 0 && $0.activeBarCount >= 0
          && $0.tailOnlyBarCount >= 0 && $0.recoveryCount >= 0
          && $0.maximumActiveRunBars >= 0
          && $0.wetBarOccupancy.isFinite
          && (0...1).contains($0.wetBarOccupancy)
          && ($0.maximumReturnToSourceDB?.isFinite ?? true)
      }
      && sourceFingerprint
        == Self.makeFingerprint(
          rootSeed: rootSeed,
          semanticFingerprint: semanticFingerprint,
          primaryPolicyVersion: primaryPolicyVersion,
          sampleRate: sampleRate,
          signalFingerprint: signalFingerprint,
          semanticValues: semanticValues,
          operatorDeltas: operatorDeltas,
          effects: effects)
  }

  package var hasMinimumDecisionEvidence: Bool {
    isStructurallyComplete
      && observedBarCount
        >= LongHorizonProfessionalPolicySchema.minimumJourneyBars
      && signalObservationCount
        >= LongHorizonProfessionalPolicySchema.minimumSignalObservationCount
      && operatorDeltas.allSatisfy {
        $0.transitionCount
          >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
      }
  }

  package func deterministicJSON() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.nonConformingFloatEncodingStrategy = .throw
    return try encoder.encode(self)
  }

  private static func makeFingerprint(
    rootSeed: UInt64,
    semanticFingerprint: String,
    primaryPolicyVersion: String,
    sampleRate: Double,
    signalFingerprint: String,
    semanticValues: [LongHorizonPolicyNamedValue],
    operatorDeltas: [LongHorizonPolicyOperatorDelta],
    effects: [LongHorizonPolicyEffectObservation]
  ) -> String {
    var hasher = LongHorizonRuntimeHasher()
    hasher.mix(LongHorizonRuntimePolicySchema.observationVersion)
    hasher.mix(rootSeed)
    hasher.mix(semanticFingerprint)
    hasher.mix(primaryPolicyVersion)
    hasher.mix(sampleRate)
    hasher.mix(signalFingerprint)
    for value in semanticValues {
      hasher.mix(value.metric.rawValue)
      hasher.mix(value.value)
    }
    for delta in operatorDeltas {
      hasher.mix(delta.sampleRate)
      hasher.mix(delta.operatorKind.rawValue)
      hasher.mix(delta.metric.rawValue)
      hasher.mix(delta.transitionCount)
      hasher.mix(delta.meanDelta)
    }
    for effect in effects {
      hasher.mix(effect.family.rawValue)
      hasher.mix(effect.observedBarCount)
      hasher.mix(effect.eligibleBarCount)
      hasher.mix(effect.activeBarCount)
      hasher.mix(effect.tailOnlyBarCount)
      hasher.mix(effect.recoveryCount)
      hasher.mix(effect.maximumActiveRunBars)
      hasher.mix(effect.wetBarOccupancy)
      hasher.mix(effect.maximumReturnToSourceDB ?? -Double.greatestFiniteMagnitude)
    }
    return hasher.hex
  }
}

extension LongHorizonProfessionalProfileEvaluator {
  package func evaluate(
    _ observation: LongHorizonRuntimePolicyObservation,
    expectedRootSeed: UInt64? = nil
  ) -> LongHorizonPolicyVerdict {
    var dimensions = Set<LongHorizonPolicyFailureDimension>()
    var failedSemantic: [LongHorizonPolicySemanticMetric] = []
    var failedOperators: [LongHorizonPolicyOperatorDelta] = []
    var failedEffects: [LongHorizonEffectFamily] = []
    guard observation.isStructurallyComplete,
      observation.engineVersion == profile.engineVersion,
      observation.primaryPolicyVersion == profile.primaryPolicyVersion,
      profile.sampleRates.contains(observation.sampleRate),
      expectedRootSeed.map({ $0 == observation.rootSeed }) ?? true
    else {
      return LongHorizonPolicyVerdict(
        accepted: false,
        failedDimensions: [.identity],
        failedSemanticMetrics: [],
        failedOperatorDeltas: [],
        failedEffectFamilies: [])
    }
    if observation.observedBarCount
      < LongHorizonProfessionalPolicySchema.minimumJourneyBars
    {
      dimensions.insert(.duration)
    }
    for value in observation.semanticValues {
      guard let bounds = profile.semanticBound(value.metric),
        bounds.contains(value.value)
      else {
        failedSemantic.append(value.metric)
        switch value.metric {
        case .dominantSemanticPeriodicity, .eventSignatureRepeatRatio:
          dimensions.insert(.semanticPeriodicity)
        case .highTensionDwellBars: dimensions.insert(.permanentPeak)
        case .recoveryBarRatio: dimensions.insert(.recoveryStarvation)
        case .matchedIdentityRecallRatio: dimensions.insert(.identityRecall)
        case .zeroAgeDebtRatio, .overdueDebtCount, .oldestDebtAgeBars:
          dimensions.insert(.dramaticDebt)
        case .maximumCapabilityRunBars:
          dimensions.insert(.capabilityFatigue)
        }
        continue
      }
    }
    for delta in observation.operatorDeltas {
      guard
        let bound = profile.operatorDeltaBounds.first(where: {
          $0.sampleRate == delta.sampleRate
            && $0.operatorKind == delta.operatorKind
            && $0.metric == delta.metric
        }),
        bound.bounds.contains(delta.meanDelta)
      else {
        failedOperators.append(delta)
        dimensions.insert(.operatorConsequence)
        continue
      }
    }
    for effect in observation.effects {
      guard
        let bound = profile.effectBounds.first(where: {
          $0.family == effect.family
        })
      else {
        failedEffects.append(effect.family)
        dimensions.insert(.effectFatigue)
        continue
      }
      let tailOccupancy =
        Double(effect.tailOnlyBarCount) / Double(effect.observedBarCount)
      let returnWithinBound =
        switch (effect.maximumReturnToSourceDB, bound.maximumReturnToSourceDB) {
        case (nil, _): true
        case (let value?, let upper?): value <= upper
        case (_?, nil): false
        }
      if effect.wetBarOccupancy > bound.maximumWetBarOccupancy
        || tailOccupancy > bound.maximumTailBarOccupancy
        || effect.maximumActiveRunBars > bound.maximumActiveRunBars
        || !returnWithinBound
      {
        failedEffects.append(effect.family)
        dimensions.insert(.effectFatigue)
      }
    }
    let orderedDimensions = LongHorizonPolicyFailureDimension.allCases.filter(
      dimensions.contains)
    return LongHorizonPolicyVerdict(
      accepted: orderedDimensions.isEmpty,
      failedDimensions: orderedDimensions,
      failedSemanticMetrics: LongHorizonPolicySemanticMetric.allCases.filter(
        Set(failedSemantic).contains),
      failedOperatorDeltas: failedOperators,
      failedEffectFamilies: LongHorizonEffectFamily.allCases.filter(
        Set(failedEffects).contains))
  }
}

extension LongHorizonProfessionalPolicy {
  package func evaluate(
    _ observation: LongHorizonRuntimePolicyObservation,
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

package enum LongHorizonFutureDecisionFactory {
  package static func make(
    observation: LongHorizonRuntimePolicyObservation,
    verdict: LongHorizonPolicyVerdict,
    policyVersion: String,
    observedThroughPhraseIndex: Int,
    observedThroughBar: Int,
    recoveryEligible: Bool
  ) -> LongHorizonTrajectoryDecision? {
    guard observation.hasMinimumDecisionEvidence,
      observedThroughPhraseIndex >= 0,
      observedThroughBar >= LongHorizonProfessionalPolicySchema.minimumJourneyBars
    else { return nil }
    if verdict.accepted {
      return LongHorizonTrajectoryDecision(
        rootSeed: observation.rootSeed,
        policyVersion: policyVersion,
        evidenceSchema: observation.schemaVersion,
        evidenceFingerprint: observation.sourceFingerprint,
        observedThroughPhraseIndex: observedThroughPhraseIndex,
        observedThroughBar: observedThroughBar,
        action: .preserve,
        reasons: [.qualified])
    }
    guard recoveryEligible, !verdict.failedDimensions.isEmpty else { return nil }
    let reasons: [LongHorizonTrajectoryDecisionReason] =
      verdict.failedDimensions.map { dimension in
        switch dimension {
        case .identity: LongHorizonTrajectoryDecisionReason.identity
        case .duration: .duration
        case .semanticPeriodicity: .semanticPeriodicity
        case .permanentPeak: .permanentPeak
        case .recoveryStarvation: .recoveryStarvation
        case .identityRecall: .identityRecall
        case .dramaticDebt: .dramaticDebt
        case .capabilityFatigue: .capabilityFatigue
        case .operatorConsequence: .operatorConsequence
        case .effectFatigue: .effectFatigue
        }
      }
    return LongHorizonTrajectoryDecision(
      rootSeed: observation.rootSeed,
      policyVersion: policyVersion,
      evidenceSchema: observation.schemaVersion,
      evidenceFingerprint: observation.sourceFingerprint,
      observedThroughPhraseIndex: observedThroughPhraseIndex,
      observedThroughBar: observedThroughBar,
      action: .recover,
      reasons: reasons)
  }
}

package struct LongHorizonFutureAdaptationUpdate: Sendable {
  package let state: LongHorizonFutureAdaptationState
  package let decision: LongHorizonTrajectoryDecision?
}

/// Bounded streaming state copied into detached phrase preparation. It owns no
/// PCM, AVAudioEngine object, callback state, renderer, or mutable plan.
package struct LongHorizonFutureAdaptationState: Sendable {
  package let schemaVersion: String
  package let rootSeed: UInt64
  package private(set) var expectedPhraseIndex: Int
  package private(set) var expectedBar: Int
  package private(set) var nextEligibleDecisionBar: Int
  package private(set) var lastDecisionFingerprint: String?

  private let profileFingerprint: String
  private let primaryPolicyVersion: String
  private var semantic: LongHorizonSemanticTrajectoryAccumulator
  private var effects: LongHorizonEffectDoseAccumulator
  private var signals: [LongHorizonSignalTrajectoryAccumulator]

  package init?(
    startingState: AutonomousSessionState,
    policy: LongHorizonProfessionalPolicy
  ) {
    guard policy.profile.isComplete,
      policy.profile.sampleRates.count
        >= LongHorizonProfessionalPolicySchema.minimumSignalRateCount
    else { return nil }
    schemaVersion = LongHorizonRuntimePolicySchema.adaptationVersion
    rootSeed = startingState.rootSeed
    expectedPhraseIndex = startingState.phraseIndex
    expectedBar = startingState.memory.totalBars
    nextEligibleDecisionBar = max(
      startingState.memory.totalBars,
      LongHorizonProfessionalPolicySchema.minimumJourneyBars)
    lastDecisionFingerprint = nil
    profileFingerprint = policy.profile.fingerprint
    primaryPolicyVersion = policy.profile.primaryPolicyVersion
    semantic = LongHorizonSemanticTrajectoryAccumulator(
      startingState: startingState)
    effects = LongHorizonEffectDoseAccumulator(
      rootSeed: startingState.rootSeed,
      startingPhraseIndex: startingState.phraseIndex,
      startingBar: startingState.memory.totalBars)
    signals = policy.profile.sampleRates.map {
      LongHorizonSignalTrajectoryAccumulator(
        rootSeed: startingState.rootSeed,
        sampleRate: $0)
    }
  }

  package var fingerprint: String {
    var hasher = LongHorizonRuntimeHasher()
    hasher.mix(schemaVersion)
    hasher.mix(rootSeed)
    hasher.mix(expectedPhraseIndex)
    hasher.mix(expectedBar)
    hasher.mix(nextEligibleDecisionBar)
    hasher.mix(profileFingerprint)
    hasher.mix(primaryPolicyVersion)
    hasher.mix(semantic.report().trajectoryFingerprint)
    let effectReport = effects.report
    hasher.mix(effectReport.phraseCount)
    hasher.mix(effectReport.barCount)
    for signal in signals {
      let report = signal.report
      hasher.mix(report.sampleRate)
      hasher.mix(report.trajectoryFingerprint)
      hasher.mix(report.observationCount)
    }
    hasher.mix(lastDecisionFingerprint ?? "none")
    return hasher.hex
  }

  package func observing(
    prepared: PreparedAutonomousPhrase,
    incomingState: AutonomousSessionState,
    policy: LongHorizonProfessionalPolicy
  ) -> LongHorizonFutureAdaptationUpdate? {
    guard schemaVersion == LongHorizonRuntimePolicySchema.adaptationVersion,
      rootSeed == incomingState.rootSeed,
      expectedPhraseIndex == incomingState.phraseIndex,
      expectedBar == incomingState.memory.totalBars,
      prepared.plan.phraseIndex == expectedPhraseIndex,
      prepared.plan.startBar == expectedBar,
      prepared.commitEligible,
      profileFingerprint == policy.profile.fingerprint,
      primaryPolicyVersion == policy.profile.primaryPolicyVersion,
      let signalEvidence = LongHorizonSignalPhraseEvidence.make(
        prepared: prepared),
      let signalIndex = policy.profile.sampleRates.firstIndex(
        of: signalEvidence.sampleRate),
      let effectEvidence = prepared.longHorizonEffectDoseEvidence
    else { return nil }

    var candidate = self
    guard
      candidate.semantic.observe(
        plan: prepared.plan,
        incomingState: incomingState) == .accepted,
      candidate.effects.observe(effectEvidence) == .accepted,
      candidate.signals[signalIndex].observe(signalEvidence) == .accepted
    else { return nil }
    let end = prepared.plan.startBar.addingReportingOverflow(
      prepared.plan.barCount)
    let nextPhrase = prepared.plan.phraseIndex.addingReportingOverflow(1)
    guard !end.overflow, !nextPhrase.overflow else { return nil }
    candidate.expectedPhraseIndex = nextPhrase.partialValue
    candidate.expectedBar = end.partialValue

    let semanticReport = candidate.semantic.report()
    let effectReport = candidate.effects.report
    let signalReport = candidate.signals[signalIndex].report
    guard
      let observation = try? LongHorizonRuntimePolicyObservation(
        semanticReport: semanticReport,
        signalReport: signalReport,
        effectReport: effectReport,
        primaryPolicyVersion: candidate.primaryPolicyVersion)
    else {
      return LongHorizonFutureAdaptationUpdate(
        state: candidate,
        decision: nil)
    }
    guard observation.hasMinimumDecisionEvidence,
      end.partialValue >= candidate.nextEligibleDecisionBar
    else {
      return LongHorizonFutureAdaptationUpdate(
        state: candidate,
        decision: nil)
    }

    let projected = incomingState.advance(
      using: prepared.plan,
      quality: prepared.qualityContinuationState,
      liveMasterHeadroom: prepared.liveMasterHeadroomContinuationState)
    let continuation = projected.memory.longHorizon
    let recoveryEligible =
      continuation.currentEpisode.operatorKind != .recover
      && (continuation.currentEpisode.startedAtBar == continuation.nextExpectedBar
        || continuation.nextExpectedBar
          >= continuation.currentEpisode.minimumHoldUntilBar)
    let verdict = policy.evaluate(
      observation,
      expectedRootSeed: incomingState.rootSeed)
    let decision = LongHorizonFutureDecisionFactory.make(
      observation: observation,
      verdict: verdict,
      policyVersion: policy.policyVersion,
      observedThroughPhraseIndex: prepared.plan.phraseIndex,
      observedThroughBar: end.partialValue,
      recoveryEligible: recoveryEligible)
    if let decision {
      let nextEligible = end.partialValue.addingReportingOverflow(
        LongHorizonRuntimePolicySchema.minimumDecisionIntervalBars)
      candidate.nextEligibleDecisionBar =
        nextEligible.overflow
        ? Int.max : nextEligible.partialValue
      candidate.lastDecisionFingerprint = decision.fingerprint
    }
    return LongHorizonFutureAdaptationUpdate(
      state: candidate,
      decision: decision)
  }
}

private struct LongHorizonRuntimeHasher {
  private var value: UInt64 = 14_695_981_039_346_656_037

  mutating func mix(_ value: UInt64) { mix(String(value)) }
  mutating func mix(_ value: Int) { mix(String(value)) }
  mutating func mix(_ value: Double) {
    mix(String(value.bitPattern, radix: 16))
  }
  mutating func mix(_ value: String) {
    for byte in value.utf8 {
      self.value ^= UInt64(byte)
      self.value &*= 1_099_511_628_211
    }
    self.value ^= 0xFF
    self.value &*= 1_099_511_628_211
  }

  var hex: String {
    let raw = String(value, radix: 16)
    return String(repeating: "0", count: max(0, 16 - raw.count)) + raw
  }
}
