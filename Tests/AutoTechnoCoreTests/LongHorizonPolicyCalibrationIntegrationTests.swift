import AutoTechnoCore
import Foundation
import Testing

@testable import AutoTechnoDSP

@Suite("Representative long-horizon policy calibration", .serialized)
struct LongHorizonPolicyCalibrationIntegrationTests {
  private let developmentRoots: [UInt64] = [
    48_291, 77_777, 90_909, 112_358, 141_421, 173_205, 246_813,
  ]
  private let holdoutRoots: [UInt64] = [271_828, 314_159]

  /// Deliberately expensive and opt-in. Each root supplies a complete
  /// four-hour canonical semantic journey plus exact primary-qualified,
  /// detached PCM checkpoints at every episode operator for both production
  /// rates. PCM remains local and is discarded after reduction.
  @Test("Generate exact development, adversarial, and disjoint holdout artifacts")
  func generateArtifacts() throws {
    guard
      ProcessInfo.processInfo.environment[
        "AUTOTECHNO_RUN_LONG_HORIZON_CALIBRATION"
      ] == "1"
    else { return }

    let corpora = try calibrationCorpora()
    let development = corpora.development
    let holdoutCorpus = corpora.holdout
    let profile = try LongHorizonProfessionalProfile(corpus: development)
    let profileEvaluator = try LongHorizonProfessionalProfileEvaluator(
      profile: profile)
    for observation in development.observations {
      let verdict = profileEvaluator.evaluate(observation)
      progress(
        "development root=\(observation.rootSeed) accepted=\(verdict.accepted) "
          + "failures=\(verdict.failedDimensions.map(\.rawValue).joined(separator: ","))")
      #expect(verdict.accepted)
    }
    let adversarial = try LongHorizonAdversarialSuiteReport(
      profile: profile,
      sourceObservation: development.observations[0])
    let holdout = try LongHorizonHoldoutQualification(
      profile: profile,
      adversarial: adversarial,
      developmentCorpus: development,
      holdoutCorpus: holdoutCorpus)
    for journey in holdout.journeys {
      progress(
        "holdout root=\(journey.rootSeed) accepted=\(journey.verdict.accepted) "
          + "failures=\(journey.verdict.failedDimensions.map(\.rawValue).joined(separator: ",")) "
          + "semantic=\(journey.verdict.failedSemanticMetrics.map(\.rawValue).joined(separator: ",")) "
          + "operators=\(journey.verdict.failedOperatorDeltas.count) "
          + "effects=\(journey.verdict.failedEffectFamilies.map(\.rawValue).joined(separator: ","))"
      )
      for delta in journey.verdict.failedOperatorDeltas {
        let bound = profile.operatorDeltaBounds.first {
          $0.sampleRate == delta.sampleRate
            && $0.operatorKind == delta.operatorKind
            && $0.metric == delta.metric
        }
        progress(
          "holdout-operator-detail root=\(journey.rootSeed) "
            + "rate=\(Int(delta.sampleRate)) "
            + "operator=\(delta.operatorKind.rawValue) "
            + "metric=\(delta.metric.rawValue) "
            + "transitions=\(delta.transitionCount) "
            + "value=\(delta.meanDelta) bounds="
            + "\(bound?.bounds.lower ?? .nan)..."
            + "\(bound?.bounds.upper ?? .nan)"
        )
      }
    }
    let policy = try LongHorizonProfessionalPolicy(
      profile: profile,
      adversarial: adversarial,
      holdout: holdout)

    #expect(adversarial.passed)
    #expect(holdout.qualified)
    #expect(holdout.journeys.allSatisfy { $0.verdict.accepted })
    #expect(!policy.policyVersion.isEmpty)
    try writeArtifacts(
      profile: profile, adversarial: adversarial, holdout: holdout)
    progress("profile=\(profile.fingerprint)")
    progress("adversarial=\(adversarial.fingerprint)")
    progress("holdout=\(holdout.fingerprint)")
  }

  private func calibrationCorpora() throws -> (
    development: LongHorizonPolicyCalibrationCorpus,
    holdout: LongHorizonPolicyCalibrationCorpus
  ) {
    if ProcessInfo.processInfo.environment[
      "AUTOTECHNO_REUSE_LONG_HORIZON_CORPORA"
    ] == "1" {
      return try loadCorpora()
    }
    let primary = try ProfessionalQualityPrimaryArtifacts.load()
    let development = try LongHorizonPolicyCalibrationCorpus(
      observations: developmentRoots.map {
        try cachedOrRenderedObservation(
          rootSeed: $0, primary: primary.evaluator)
      })
    let holdout = try LongHorizonPolicyCalibrationCorpus(
      observations: holdoutRoots.map {
        try cachedOrRenderedObservation(
          rootSeed: $0, primary: primary.evaluator)
      })
    try writeCorpora(development: development, holdout: holdout)
    return (development, holdout)
  }

  private func cachedOrRenderedObservation(
    rootSeed: UInt64,
    primary: ProfessionalQualityPrimaryEvaluator
  ) throws -> LongHorizonPolicyObservation {
    let url = try outputDirectory().appendingPathComponent(
      "long-horizon-observation-local-\(rootSeed)-v2.json")
    if ProcessInfo.processInfo.environment[
      "AUTOTECHNO_REUSE_LONG_HORIZON_OBSERVATIONS"
    ] == "1", FileManager.default.fileExists(atPath: url.path) {
      let observation =
        try LongHorizonPolicyObservation
        .decodeDeterministicJSON(Data(contentsOf: url))
      guard observation.rootSeed == rootSeed,
        observation.primaryPolicyVersion == primary.policyVersion
      else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
      progress(
        "reused root=\(rootSeed) source=\(observation.sourceFingerprint)")
      return observation
    }
    let observation = try renderObservation(rootSeed: rootSeed, primary: primary)
    try observation.deterministicJSON().write(to: url)
    return observation
  }

  private func loadCorpora() throws -> (
    development: LongHorizonPolicyCalibrationCorpus,
    holdout: LongHorizonPolicyCalibrationCorpus
  ) {
    let directory = try outputDirectory()
    let development =
      try LongHorizonPolicyCalibrationCorpus
      .decodeDeterministicJSON(
        Data(
          contentsOf: directory.appendingPathComponent(
            "long-horizon-development-corpus-local-v2.json")))
    let holdout =
      try LongHorizonPolicyCalibrationCorpus
      .decodeDeterministicJSON(
        Data(
          contentsOf: directory.appendingPathComponent(
            "long-horizon-holdout-corpus-local-v2.json")))
    guard development.observations.map(\.rootSeed) == developmentRoots.sorted(),
      holdout.observations.map(\.rootSeed) == holdoutRoots.sorted()
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    progress(
      "reused development=\(development.fingerprint) holdout=\(holdout.fingerprint)")
    return (development, holdout)
  }

  private func writeCorpora(
    development: LongHorizonPolicyCalibrationCorpus,
    holdout: LongHorizonPolicyCalibrationCorpus
  ) throws {
    let directory = try outputDirectory()
    try development.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "long-horizon-development-corpus-local-v2.json"))
    try holdout.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "long-horizon-holdout-corpus-local-v2.json"))
  }

  private func outputDirectory() throws -> URL {
    guard
      let outputDirectory = ProcessInfo.processInfo.environment[
        "AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY"
      ], !outputDirectory.isEmpty
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    return directory
  }

  @Test("Render one exact diagnostic root")
  func renderDiagnosticRoot() throws {
    guard
      let rawRoot = ProcessInfo.processInfo.environment[
        "AUTOTECHNO_LONG_HORIZON_DIAGNOSTIC_ROOT"
      ], let rootSeed = UInt64(rawRoot)
    else { return }
    let primary = try ProfessionalQualityPrimaryArtifacts.load()
    let observation = try renderObservation(
      rootSeed: rootSeed, primary: primary.evaluator)
    let url = try outputDirectory().appendingPathComponent(
      "long-horizon-observation-local-\(rootSeed)-v2.json")
    try observation.deterministicJSON().write(to: url)
    progress(
      "diagnostic root=\(rootSeed) source=\(observation.sourceFingerprint) "
        + "semantic=\(observation.semanticFingerprint) "
        + "signals=\(observation.signalFingerprints.joined(separator: ","))")
  }

  private func renderObservation(
    rootSeed: UInt64,
    primary: ProfessionalQualityPrimaryEvaluator
  ) throws -> LongHorizonPolicyObservation {
    let director = AutonomousSessionDirector(rootSeed: rootSeed)
    let journey = canonicalJourney(rootSeed: rootSeed)
    progress(
      "planned root=\(rootSeed) bars=\(journey.semantic.observedBarCount) "
        + "phrases=\(journey.semantic.observedPhraseCount) "
        + "checkpoints=\(journey.checkpoints.count)")
    var signal44 = LongHorizonSignalTrajectoryAccumulator(
      rootSeed: rootSeed, sampleRate: 44_100)
    var signal48 = LongHorizonSignalTrajectoryAccumulator(
      rootSeed: rootSeed, sampleRate: 48_000)
    var effectPhrases: [LongHorizonEffectDosePhraseEvidence] = []
    for checkpoint in journey.checkpoints {
      if let operatorKind = checkpoint.plan.longHorizonEnergyCoordination.operatorKind,
        hasCompleteMetricCoverage(
          for: operatorKind, in: signal44.report),
        hasCompleteMetricCoverage(
          for: operatorKind, in: signal48.report)
      {
        continue
      }
      var preparedByRate: [PreparedAutonomousPhrase] = []
      for sampleRate in [44_100.0, 48_000.0] {
        var incomingRenderState = RenderState()
        incomingRenderState.barIndex = checkpoint.plan.startBar
        let neverCancelled: @Sendable () -> Bool = { false }
        var retry = AutonomousQualityRetryContinuation()
        var accepted: PreparedAutonomousPhrase?
        for ordinal in 0...AutonomousQualityRetryContinuation.maximumOrdinal {
          let retryPlan = director.plan(
            from: checkpoint.state,
            qualityRetryOrdinal: ordinal)
          let preparedResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: retryPlan,
            sessionSeed: rootSeed,
            memory: checkpoint.state.memory,
            sampleRate: sampleRate,
            incomingRenderState: incomingRenderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: checkpoint.state.quality,
            evaluator: primary,
            cancellationRequested: neverCancelled)
          guard let prepared = preparedResult else {
            progress(
              "missing root=\(rootSeed) rate=\(Int(sampleRate)) "
                + "phrase=\(checkpoint.plan.phraseIndex) retry=\(ordinal)")
            break
          }
          let assessment = primary.assessment(
            of: prepared.selectedCandidateEvidence)
          if prepared.commitEligible && assessment.accepted {
            accepted = prepared
            if ordinal > 0 {
              progress(
                "retry-selected root=\(rootSeed) rate=\(Int(sampleRate)) "
                  + "phrase=\(checkpoint.plan.phraseIndex) retry=\(ordinal)")
            }
            break
          }
          progress(
            "rejected root=\(rootSeed) rate=\(Int(sampleRate)) "
              + "phrase=\(checkpoint.plan.phraseIndex) retry=\(ordinal) "
              + "decision=\(prepared.qualityDecision.outcome.rawValue) "
              + "reasons=\(prepared.qualityDecision.reasonCodes.map(\.rawValue).joined(separator: ",")) "
              + "failed=\(assessment.verdicts.flatMap(\.failedMetrics).map(\.rawValue).joined(separator: ","))"
          )
          let next = retry.recordingCalibratedRejection(
            decision: prepared.qualityDecision,
            targetPhraseIndex: retryPlan.phraseIndex)
          guard next.ordinal(for: retryPlan.phraseIndex) > ordinal else {
            break
          }
          retry = next
        }
        guard let accepted else { break }
        preparedByRate.append(accepted)
      }
      guard preparedByRate.count == 2,
        preparedByRate.allSatisfy(\.commitEligible),
        let evidence44 = preparedByRate[0].longHorizonSignalTrajectoryEvidence,
        let evidence48 = preparedByRate[1].longHorizonSignalTrajectoryEvidence,
        let effect44 = preparedByRate[0].longHorizonEffectDoseEvidence
      else { continue }
      #expect(signal44.observe(evidence44) == .accepted)
      #expect(signal48.observe(evidence48) == .accepted)
      effectPhrases.append(effect44)
      let finalKick44 = preparedByRate[0].selectedCandidateEvidence
        .automaticMix.last?.gains.first { $0.role == MixRole.kick.rawValue }?
        .gainDB ?? .nan
      let finalKick48 = preparedByRate[1].selectedCandidateEvidence
        .automaticMix.last?.gains.first { $0.role == MixRole.kick.rawValue }?
        .gainDB ?? .nan
      progress(
        "selected root=\(rootSeed) phrase=\(checkpoint.plan.phraseIndex) "
          + "kind=\(checkpoint.plan.kind.rawValue) "
          + "operator=\(checkpoint.plan.longHorizonEnergyCoordination.operatorKind?.rawValue ?? "none")"
          + " kick44=\(finalKick44) kick48=\(finalKick48)"
          + " lufs44=\(evidence44.signal.integratedLoudnessLUFS)"
          + " crest44=\(evidence44.signal.meanBarCrestFactorDB)"
          + " transients44=\(evidence44.signal.transientDensityPerSecond)"
          + " masking44=\(evidence44.signal.maximumMaskingOverlap)"
          + " lufs48=\(evidence48.signal.integratedLoudnessLUFS)"
          + " crest48=\(evidence48.signal.meanBarCrestFactorDB)"
          + " transients48=\(evidence48.signal.transientDensityPerSecond)"
          + " masking48=\(evidence48.signal.maximumMaskingOverlap)"
      )
      if hasCompleteOperatorCoverage(signal44.report)
        && hasCompleteOperatorCoverage(signal48.report)
      {
        break
      }
    }
    let signalReports = [signal44.report, signal48.report]
    for report in signalReports {
      #expect(report.availability == .available)
      #expect(report.operatorCounts.allSatisfy { $0.observationCount > 0 })
      #expect(
        report.operatorTransitions.allSatisfy {
          $0.transitionCount
            >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
            && $0.metricDeltas.allSatisfy {
              $0.observationCount
                >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
            }
        })
      progress(
        "complete root=\(rootSeed) rate=\(Int(report.sampleRate)) "
          + "observations=\(report.observationCount) omitted=\(report.omittedPhraseCount) "
          + "transitions=\(report.operatorTransitions.map { "\($0.operatorKind.rawValue):\($0.transitionCount)" }.joined(separator: ",")) "
          + "signal=\(report.trajectoryFingerprint)")
    }
    return try LongHorizonPolicyObservation(
      semanticReport: journey.semantic,
      signalReports: signalReports,
      effectPhrases: effectPhrases,
      primaryPolicyVersion: primary.policyVersion)
  }

  private func canonicalJourney(rootSeed: UInt64) -> (
    semantic: LongHorizonSemanticTrajectoryReport,
    checkpoints: [CalibrationCheckpoint]
  ) {
    let minimumJourneyBars = 7_800
    let maximumCoverageBars = 10_400
    let director = AutonomousSessionDirector(rootSeed: rootSeed)
    var state = director.initialState()
    var semantic = LongHorizonSemanticTrajectoryAccumulator(
      rootSeed: rootSeed, startingPhraseIndex: 0, startingBar: 0)
    var checkpoints: [CalibrationCheckpoint] = []
    var operatorCandidateCounts: [LongHorizonEpisodeOperator: Int] = [:]

    while state.memory.totalBars < minimumJourneyBars
      || (state.memory.totalBars < maximumCoverageBars
        && !hasMinimumOperatorCandidateCoverage(operatorCandidateCounts))
    {
      let plan = director.plan(from: state)
      let current = CalibrationCheckpoint(state: state, plan: plan)
      #expect(semantic.observe(plan: plan, incomingState: state) == .accepted)
      if plan.phraseIndex >= 16,
        let operatorKind = plan.longHorizonEnergyCoordination.operatorKind,
        phraseKind(plan.kind, expresses: operatorKind),
        operatorCandidateCounts[operatorKind, default: 0] < 24
      {
        checkpoints.append(current)
        operatorCandidateCounts[operatorKind, default: 0] += 1
      }
      state.advancePlanning(using: plan)
    }
    #expect(hasMinimumOperatorCandidateCoverage(operatorCandidateCounts))
    return (semantic.report(), checkpoints)
  }

  private func hasMinimumOperatorCandidateCoverage(
    _ counts: [LongHorizonEpisodeOperator: Int]
  ) -> Bool {
    LongHorizonEpisodeOperator.allCases.allSatisfy {
      counts[$0, default: 0]
        >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
    }
  }

  private func phraseKind(
    _ phraseKind: AutonomousPhraseKind,
    expresses operatorKind: LongHorizonEpisodeOperator
  ) -> Bool {
    switch operatorKind {
    case .maintain: phraseKind == .lock
    case .rise: phraseKind == .contrast
    case .recover: phraseKind == .majorBreak
    case .reframe: phraseKind == .contrast || phraseKind == .majorBreak
    case .payoff: phraseKind == .energyRelease
    case .recall: phraseKind == .identityReturn
    }
  }

  private func hasCompleteOperatorCoverage(
    _ report: LongHorizonSignalTrajectoryReport
  ) -> Bool {
    report.availability == .available
      && report.operatorCounts.allSatisfy { $0.observationCount > 0 }
      && report.operatorTransitions.allSatisfy {
        $0.transitionCount
          >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
          && $0.metricDeltas.allSatisfy {
            $0.observationCount
              >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
          }
      }
  }

  private func hasCompleteMetricCoverage(
    for operatorKind: LongHorizonEpisodeOperator,
    in report: LongHorizonSignalTrajectoryReport
  ) -> Bool {
    guard let transition = report.operatorTransitions.first(where: {
      $0.operatorKind == operatorKind
    }) else { return false }
    return transition.transitionCount
      >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
      && transition.metricDeltas.count == LongHorizonSignalMetric.allCases.count
      && transition.metricDeltas.allSatisfy {
        $0.observationCount
          >= LongHorizonProfessionalPolicySchema.minimumOperatorTransitionCount
      }
  }

  private func writeArtifacts(
    profile: LongHorizonProfessionalProfile,
    adversarial: LongHorizonAdversarialSuiteReport,
    holdout: LongHorizonHoldoutQualification
  ) throws {
    let directory = try outputDirectory()
    try profile.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "\(LongHorizonProfessionalPolicyArtifacts.profileResource).json"))
    try adversarial.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "\(LongHorizonProfessionalPolicyArtifacts.adversarialResource).json"))
    try holdout.deterministicJSON().write(
      to: directory.appendingPathComponent(
        "\(LongHorizonProfessionalPolicyArtifacts.holdoutResource).json"))
  }

  private func progress(_ message: String) {
    guard
      let data = "AUTOTECHNO_LONG_HORIZON_CALIBRATION \(message)\n"
        .data(using: .utf8)
    else { return }
    FileHandle.standardError.write(data)
  }
}

private struct CalibrationCheckpoint {
  let state: AutonomousSessionState
  let plan: AutonomousPhrasePlan
}
