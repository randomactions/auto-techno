import AutoTechnoCore
import Foundation
import Testing

@testable import AutoTechnoDSP

@Suite("Long-horizon realized signal trajectory")
struct LongHorizonSignalTrajectoryTests {
  @Test("One accepted detached phrase binds semantic target to exact PCM evidence")
  func detachedPhraseEvidenceIsExactAndSignalOnly() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    let state = director.initialState()
    let plan = director.plan(from: state)
    var renderState = RenderState()
    renderState.barIndex = state.memory.totalBars
    let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
      plan: plan,
      sessionSeed: state.rootSeed,
      memory: state.memory,
      sampleRate: 8_000,
      incomingRenderState: renderState,
      incomingGraphState: GeneratedDSPContinuationState(),
      previousGraph: nil,
      incomingQualityState: state.quality,
      evaluator: AcceptingPrimaryTestEvaluator(),
      cancellationRequested: { false })
    if let failure = outcome.failure {
      Issue.record("Preparation failed at \(failure.stage.rawValue): \(failure.code.rawValue) \(failure.details)")
    }
    let accepted = try #require(outcome.preparedPhrase)
    let evidence = try #require(accepted.longHorizonSignalTrajectoryEvidence)
    let encoded = try JSONEncoder().encode(evidence)
    let json = String(decoding: encoded, as: UTF8.self)

    #expect(accepted.commitEligible)
    #expect(evidence.isComplete)
    #expect(evidence.coordination == plan.longHorizonEnergyCoordination)
    #expect(evidence.planFingerprint == accepted.selectedCandidateEvidence.planFingerprint)
    #expect(evidence.pcmFingerprint == accepted.audioPreflight.quality.sampleHash)
    #expect(evidence.bars.count == plan.barCount)
    #expect(evidence.signal.metricValues.count >= 15)
    #expect(encoded.count < 100_000)
    #expect(!json.contains("\"left\":"))
    #expect(!json.contains("\"right\":"))
    #expect(!json.contains("samples"))
  }

  @Test("Eight-hour checkpoints retain fixed-capacity signal and episode state")
  func eightHourTrajectoryIsBounded() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    var state = director.initialState()
    var accumulator = LongHorizonSignalTrajectoryAccumulator(
      rootSeed: state.rootSeed,
      sampleRate: 8_000)

    while state.memory.totalBars < 15_600 {
      let plan = director.plan(from: state)
      let evidence = syntheticEvidence(
        plan: plan,
        rootSeed: state.rootSeed,
        signalOffset: Double(plan.phraseIndex % 17) * 0.05)
      #expect(accumulator.observe(evidence) == .accepted)
      state.advancePlanning(using: plan)
    }

    let report = accumulator.report
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let encoded = try encoder.encode(report)
    #expect(report.availability == .available)
    #expect(report.observationCount == state.phraseIndex)
    #expect(report.renderedBarCount == state.memory.totalBars)
    #expect(report.omittedPhraseCount == 0)
    #expect(report.omittedBarCount == 0)
    #expect(
      report.recentPhrases.count
        == LongHorizonSignalTrajectorySchema.recentPhraseCapacity)
    #expect(
      report.recentTransitions.count
        == LongHorizonSignalTrajectorySchema.recentTransitionCapacity)
    #expect(
      report.recentEpisodes.count
        == LongHorizonSignalTrajectorySchema.recentEpisodeCapacity)
    #expect(report.metrics.count == LongHorizonSignalMetric.allCases.count)
    #expect(report.operatorCounts.allSatisfy { $0.observationCount > 0 })
    #expect(report.operatorTransitions.allSatisfy { $0.transitionCount > 0 })
    #expect(
      report.operatorTransitions.allSatisfy {
        $0.metricDeltas.count == LongHorizonSignalMetric.allCases.count
      })
    #expect(report.qualificationStatus == "unavailable")
    #expect(
      report.qualificationReason
        == "no-calibrated-long-horizon-policy")
    #expect(report.trajectoryFingerprint.count == 16)
    #expect(report.trajectoryFingerprint == "571eb657d7754172")
    #expect(encoded.count < 500_000)
    print(
      "LONG_HORIZON_SIGNAL_8H observations=\(report.observationCount) "
        + "bars=\(report.renderedBarCount) episodes=\(report.recentEpisodes.count) "
        + "fingerprint=\(report.trajectoryFingerprint)")
  }

  @Test("Sparse checkpoint gaps are explicit and never presented as contiguous PCM")
  func sparseCheckpointGapsAreTruthful() {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    var state = director.initialState()
    var accumulator = LongHorizonSignalTrajectoryAccumulator(
      rootSeed: state.rootSeed,
      sampleRate: 8_000)
    var observed = 0

    while state.memory.totalBars < 2_000 {
      let plan = director.plan(from: state)
      if plan.phraseIndex.isMultiple(of: 7) {
        #expect(
          accumulator.observe(
            syntheticEvidence(
              plan: plan,
              rootSeed: state.rootSeed,
              signalOffset: Double(observed) * 0.1)) == .accepted)
        observed += 1
      }
      state.advancePlanning(using: plan)
    }

    let report = accumulator.report
    #expect(report.observationCount == observed)
    #expect(report.renderedBarCount < state.memory.totalBars)
    #expect(report.omittedPhraseCount > 0)
    #expect(report.omittedBarCount > 0)
    #expect(report.recentTransitions.allSatisfy { $0.omittedPhraseCount > 0 })
    #expect(report.recentTransitions.allSatisfy { $0.omittedBarCount > 0 })
  }

  @Test("Semantic intent and physical delta remain independently inspectable")
  func semanticAndPhysicalEvidenceStaySeparate() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    var state = director.initialState()
    let firstPlan = director.plan(from: state)
    state.advancePlanning(using: firstPlan)
    let secondPlan = director.plan(from: state)
    let first = syntheticEvidence(
      plan: firstPlan,
      rootSeed: state.rootSeed,
      signalOffset: 0)
    let second = syntheticEvidence(
      plan: secondPlan,
      rootSeed: state.rootSeed,
      signalOffset: 3)
    var accumulator = LongHorizonSignalTrajectoryAccumulator(
      rootSeed: state.rootSeed,
      sampleRate: 8_000)

    #expect(accumulator.observe(first) == .accepted)
    #expect(accumulator.observe(second) == .accepted)
    let transition = try #require(accumulator.report.recentTransitions.last)
    let loudnessDelta = transition.metricDeltas.first {
      $0.metric == .integratedLoudnessLUFS
    }
    #expect(transition.target == second.coordination.target)
    #expect(transition.operatorKind == second.coordination.operatorKind)
    #expect(loudnessDelta?.value == 3)
  }

  @Test("Invalid rate and phrase order fail closed without mutating accepted summaries")
  func invalidEvidenceIsTransactional() {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    let state = director.initialState()
    let plan = director.plan(from: state)
    let valid = syntheticEvidence(plan: plan, rootSeed: state.rootSeed)
    let wrongRate = syntheticEvidence(
      plan: nextPlan(after: plan, director: director, state: state),
      rootSeed: state.rootSeed,
      sampleRate: 44_100)
    var rateAccumulator = LongHorizonSignalTrajectoryAccumulator(
      rootSeed: state.rootSeed,
      sampleRate: 8_000)
    #expect(rateAccumulator.observe(valid) == .accepted)
    let accepted = rateAccumulator.report
    #expect(
      rateAccumulator.observe(wrongRate)
        == .unavailable(.sampleRateMismatch))
    let failed = rateAccumulator.report
    #expect(failed.observationCount == accepted.observationCount)
    #expect(failed.renderedBarCount == accepted.renderedBarCount)
    #expect(failed.metrics == accepted.metrics)

    var orderAccumulator = LongHorizonSignalTrajectoryAccumulator(
      rootSeed: state.rootSeed,
      sampleRate: 8_000)
    #expect(orderAccumulator.observe(valid) == .accepted)
    #expect(
      orderAccumulator.observe(valid)
        == .unavailable(.phraseOrderInvalid))
    #expect(orderAccumulator.report.observationCount == 1)
  }

  @Test("Evidence and reports replay byte-for-byte")
  func trajectoryReplayIsDeterministic() throws {
    let director = AutonomousSessionDirector(rootSeed: 90_909)
    var firstState = director.initialState()
    var replayState = director.initialState()
    var first = LongHorizonSignalTrajectoryAccumulator(
      rootSeed: firstState.rootSeed,
      sampleRate: 8_000)
    var replay = LongHorizonSignalTrajectoryAccumulator(
      rootSeed: replayState.rootSeed,
      sampleRate: 8_000)
    for index in 0..<80 {
      let firstPlan = director.plan(from: firstState)
      let replayPlan = director.plan(from: replayState)
      #expect(firstPlan == replayPlan)
      #expect(
        first.observe(
          syntheticEvidence(
            plan: firstPlan,
            rootSeed: firstState.rootSeed,
            signalOffset: Double(index % 11) * 0.07)) == .accepted)
      #expect(
        replay.observe(
          syntheticEvidence(
            plan: replayPlan,
            rootSeed: replayState.rootSeed,
            signalOffset: Double(index % 11) * 0.07)) == .accepted)
      firstState.advancePlanning(using: firstPlan)
      replayState.advancePlanning(using: replayPlan)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    #expect(first.report == replay.report)
    #expect(try encoder.encode(first.report) == encoder.encode(replay.report))
  }

  @Test("One prepared phrase advances only detached future-adaptation evidence")
  func preparedPhraseAdvancesFutureAdaptationOffCallback() throws {
    let artifacts = try qualifiedArtifacts()
    let policy = try LongHorizonProfessionalPolicy(
      profile: artifacts.profile,
      adversarial: artifacts.adversarial,
      holdout: artifacts.holdout)
    let sampleRate = try #require(artifacts.profile.sampleRates.first)
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    let state = director.initialState()
    let plan = director.plan(from: state)
    var renderState = RenderState()
    renderState.barIndex = state.memory.totalBars
    let preparedCandidate = AutonomousPhrasePreparer.prepareIfNotCancelled(
      plan: plan,
      sessionSeed: state.rootSeed,
      memory: state.memory,
      sampleRate: sampleRate,
      incomingRenderState: renderState,
      incomingGraphState: GeneratedDSPContinuationState(),
      previousGraph: nil,
      incomingQualityState: state.quality,
      evaluator: AcceptingPrimaryTestEvaluator(),
      cancellationRequested: { false })
    let prepared = try #require(preparedCandidate)
    let initial = try #require(LongHorizonFutureAdaptationState(
      startingState: state,
      policy: policy))
    let replay = try #require(LongHorizonFutureAdaptationState(
      startingState: state,
      policy: policy))
    let first = try #require(initial.observing(
      prepared: prepared,
      incomingState: state,
      policy: policy))
    let second = try #require(replay.observing(
      prepared: prepared,
      incomingState: state,
      policy: policy))

    #expect(first.decision == nil)
    #expect(first.state.expectedPhraseIndex == 1)
    #expect(first.state.expectedBar == plan.barCount)
    #expect(first.state.fingerprint != initial.fingerprint)
    #expect(first.state.fingerprint == second.state.fingerprint)
    #expect(first.state.nextEligibleDecisionBar == 7_200)
    let invalid = initial.observing(
      prepared: prepared,
      incomingState: AutonomousSessionDirector(rootSeed: 90_909)
        .initialState(),
      policy: policy
    )
    #expect(invalid.map { _ in false } ?? true)
  }
}

private func nextPlan(
  after plan: AutonomousPhrasePlan,
  director: AutonomousSessionDirector,
  state: AutonomousSessionState
) -> AutonomousPhrasePlan {
  var advanced = state
  advanced.advancePlanning(using: plan)
  return director.plan(from: advanced)
}

private func syntheticEvidence(
  plan: AutonomousPhrasePlan,
  rootSeed: UInt64,
  sampleRate: Double = 8_000,
  signalOffset: Double = 0
) -> LongHorizonSignalPhraseEvidence {
  let barEvidence = plan.resolvedBars.map { resolved in
    LongHorizonSignalBarEvidence(
      bar: resolved.performance.bar,
      loudnessLUFS: -24 + signalOffset,
      spectralCentroidHz: 1_100 + signalOffset * 10,
      transientDensityPerSecond: 2 + signalOffset * 0.01,
      crestFactorDB: 12 - signalOffset * 0.05,
      maximumMaskingOverlap: min(1, 0.2 + signalOffset * 0.001),
      wetToDryDB: -18 + signalOffset * 0.1,
      graphOutputToInputDB: -0.5 + signalOffset * 0.01,
      finite: true)
  }
  let signal = LongHorizonRealizedSignalVector(
    integratedLoudnessLUFS: -24 + signalOffset,
    maximumMomentaryLoudnessLUFS: -20 + signalOffset,
    truePeakDBTP: -3 + signalOffset * 0.01,
    meanBarCrestFactorDB: 12 - signalOffset * 0.05,
    spectralCentroidHz: 1_100 + signalOffset * 10,
    spectralCentroidSpreadHz: 700 + signalOffset * 5,
    transientDensityPerSecond: 2 + signalOffset * 0.01,
    positiveSpectralFluxMean: 0.1 + signalOffset * 0.001,
    lowEnergyRatio: 0.5,
    midEnergyRatio: 0.35,
    highEnergyRatio: 0.15,
    maximumMaskingOverlap: min(1, 0.2 + signalOffset * 0.001),
    meanWetToDryDB: -18 + signalOffset * 0.1,
    stereoCorrelation: 0.7,
    lowStereoCorrelation: 0.99,
    movementScore: min(1, 0.2 + signalOffset * 0.001))
  let base = UInt64(plan.phraseIndex + 1)
  return LongHorizonSignalPhraseEvidence(
    rootSeed: rootSeed,
    phraseIndex: plan.phraseIndex,
    startBar: plan.startBar,
    phraseKind: plan.kind,
    coordination: plan.longHorizonEnergyCoordination,
    sampleRate: sampleRate,
    planFingerprint: AutonomousTypedFingerprint.plan(plan),
    candidateEvidenceFingerprint: fixedHex(base &* 17),
    pcmFingerprint: fixedHex(base &* 31),
    hardGatesPassed: true,
    signal: signal,
    bars: barEvidence)
}

private func fixedHex(_ value: UInt64) -> String {
  let raw = String(value, radix: 16)
  return String(repeating: "0", count: 16 - raw.count) + raw
}
