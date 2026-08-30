import AutoTechnoCore
import Foundation
import Testing

@testable import AutoTechnoDSP

@Suite("Long-horizon calibrated professional policy")
struct LongHorizonProfessionalPolicyTests {
  @Test("Diverse development, adversarial attacks, and disjoint holdout form one policy")
  func completeQualificationChain() throws {
    let artifacts = try qualifiedArtifacts()
    let policy = try LongHorizonProfessionalPolicy(
      profile: artifacts.profile,
      adversarial: artifacts.adversarial,
      holdout: artifacts.holdout)

    #expect(
      artifacts.development.observations.count
        == LongHorizonProfessionalPolicySchema.minimumDevelopmentJourneyCount)
    #expect(
      artifacts.profile.developmentJourneyCount
        == LongHorizonProfessionalPolicySchema.minimumDevelopmentJourneyCount)
    #expect(artifacts.profile.sampleRates == [8_000, 12_000])
    #expect(artifacts.adversarial.passed)
    #expect(
      artifacts.adversarial.cases.map(\.attack)
        == LongHorizonAdversarialAttack.allCases)
    #expect(artifacts.adversarial.cases.allSatisfy { $0.rejected })
    #expect(artifacts.holdout.qualified)
    #expect(artifacts.holdout.journeys.count == 2)
    #expect(artifacts.holdout.journeys.allSatisfy { $0.verdict.accepted })
    #expect(
      policy.policyVersion.hasPrefix(
        LongHorizonProfessionalPolicySchema.policyFamilyVersion))
    #expect(policy.evaluate(artifacts.holdoutCorpus.observations[0]).accepted)
  }

  @Test("Every policy dimension is independent and reason coded")
  func nonCompensableDimensions() throws {
    let artifacts = try qualifiedArtifacts()
    let evaluator = try LongHorizonProfessionalProfileEvaluator(
      profile: artifacts.profile)
    let source = artifacts.development.observations[0]

    #expect(evaluator.evaluate(source).accepted)
    for adversarial in artifacts.adversarial.cases {
      #expect(adversarial.rejected)
      #expect(!adversarial.failedDimensions.isEmpty)
    }
    #expect(
      artifacts.adversarial.cases.first(where: {
        $0.attack == .permanentPeak
      })?.failedDimensions.contains(.permanentPeak) == true)
    #expect(
      artifacts.adversarial.cases.first(where: {
        $0.attack == .semanticSignalMismatch
      })?.failedDimensions.contains(.operatorConsequence) == true)
    #expect(
      artifacts.adversarial.cases.first(where: {
        $0.attack == .effectWetnessRatchet
      })?.failedDimensions.contains(.effectFatigue) == true)
  }

  @Test("Holdout roots and source identities must be disjoint")
  func holdoutMustBeDisjoint() throws {
    let development = try LongHorizonPolicyCalibrationCorpus(
      observations: longHorizonDevelopmentSeeds.map {
        makeObservation(rootSeed: $0)
      })
    let profile = try LongHorizonProfessionalProfile(corpus: development)
    let adversarial = try LongHorizonAdversarialSuiteReport(
      profile: profile,
      sourceObservation: development.observations[0])
    let overlap = try LongHorizonPolicyCalibrationCorpus(
      observations: [
        makeObservation(rootSeed: 7),
        makeObservation(rootSeed: 112_358),
      ])

    #expect(throws: LongHorizonProfessionalPolicyError.holdoutFailure) {
      try LongHorizonHoldoutQualification(
        profile: profile,
        adversarial: adversarial,
        developmentCorpus: development,
        holdoutCorpus: overlap)
    }
  }

  @Test("Observed overdue debt is bounded without becoming compensable")
  func overdueDebtIsCalibratedIndependently() throws {
    let development = try LongHorizonPolicyCalibrationCorpus(
      observations: zip(
        longHorizonDevelopmentSeeds,
        [2.0, 3.0, 4.0, 5.0, 4.5, 3.5, 2.5]
      ).map {
        makeObservation(rootSeed: $0.0, overdueDebtCount: $0.1)
      })
    let profile = try LongHorizonProfessionalProfile(corpus: development)
    let evaluator = try LongHorizonProfessionalProfileEvaluator(profile: profile)
    let representative = makeObservation(rootSeed: 99, overdueDebtCount: 5)
    let excessive = makeObservation(rootSeed: 100, overdueDebtCount: 12)
    let noOutstandingAge = makeObservation(
      rootSeed: 101, overdueDebtCount: 0, oldestDebtAgeBars: 0)

    #expect(evaluator.evaluate(representative).accepted)
    #expect(evaluator.evaluate(noOutstandingAge).accepted)
    let verdict = evaluator.evaluate(excessive)
    #expect(!verdict.accepted)
    #expect(verdict.failedDimensions == [.dramaticDebt])
    #expect(verdict.failedSemanticMetrics == [.overdueDebtCount])
  }

  @Test("Sparse operator means retain finite-sample uncertainty floors")
  func sparseOperatorUncertaintyFloors() throws {
    let development = try LongHorizonPolicyCalibrationCorpus(
      observations: longHorizonDevelopmentSeeds.map {
        makeObservation(rootSeed: $0)
      })
    let profile = try LongHorizonProfessionalProfile(corpus: development)

    for (metric, expectedFloor) in [
      (LongHorizonSignalMetric.spectralCentroidHz, 2_500),
      (LongHorizonSignalMetric.integratedLoudnessLUFS, 1.65),
      (.meanBarCrestFactorDB, 1.67),
      (.transientDensityPerSecond, 0.55),
    ] {
      let values = development.observations.compactMap { observation in
        observation.operatorDeltas.first {
          $0.sampleRate == 8_000 && $0.operatorKind == .maintain
            && $0.metric == metric
        }?.meanDelta
      }
      let lower = try #require(values.min())
      let upper = try #require(values.max())
      let calibrated = try #require(profile.operatorDeltaBounds.first {
        $0.sampleRate == 8_000 && $0.operatorKind == .maintain
          && $0.metric == metric
      })

      #expect(calibrated.bounds.lower == lower - expectedFloor)
      #expect(calibrated.bounds.upper == upper + expectedFloor)
    }
  }

  @Test("Insufficient duration, rate coverage, and journey diversity cannot calibrate")
  func incompleteEvidenceCannotCalibrate() throws {
    let twoJourneys = try LongHorizonPolicyCalibrationCorpus(
      observations: [UInt64(7), 13].map { makeObservation(rootSeed: $0) })
    #expect(throws: LongHorizonProfessionalPolicyError.insufficientEvidence) {
      try LongHorizonProfessionalProfile(corpus: twoJourneys)
    }

    let short = makeObservation(rootSeed: 99, observedBarCount: 1_000)
    let shortCorpus = try LongHorizonPolicyCalibrationCorpus(
      observations: [
        short,
        makeObservation(rootSeed: 100),
        makeObservation(rootSeed: 101),
        makeObservation(rootSeed: 102),
        makeObservation(rootSeed: 103),
        makeObservation(rootSeed: 104),
        makeObservation(rootSeed: 105),
      ])
    #expect(throws: LongHorizonProfessionalPolicyError.insufficientEvidence) {
      try LongHorizonProfessionalProfile(corpus: shortCorpus)
    }

    let oneRate = makeObservation(rootSeed: 103, sampleRates: [8_000])
    #expect(!oneRate.isComplete)
  }

  @Test("Reduced observations and qualification artifacts replay byte for byte")
  func deterministicReplay() throws {
    let first = try qualifiedArtifacts()
    let replay = try qualifiedArtifacts()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    #expect(first.development == replay.development)
    #expect(first.profile == replay.profile)
    #expect(first.adversarial == replay.adversarial)
    #expect(first.holdout == replay.holdout)
    #expect(
      try encoder.encode(first.development)
        == encoder.encode(replay.development))
    #expect(try encoder.encode(first.profile) == encoder.encode(replay.profile))
    #expect(
      try encoder.encode(first.adversarial)
        == encoder.encode(replay.adversarial))
    #expect(try encoder.encode(first.holdout) == encoder.encode(replay.holdout))
    #expect(
      try LongHorizonPolicyCalibrationCorpus.decodeDeterministicJSON(
        first.development.deterministicJSON()) == first.development)
    #expect(
      try LongHorizonPolicyObservation.decodeDeterministicJSON(
        first.development.observations[0].deterministicJSON())
        == first.development.observations[0])
  }

  @Test("Bundled v12 long-horizon artifacts activate the exact engine v44 policy")
  func bundledArtifacts() throws {
    for name in [
      LongHorizonProfessionalPolicyArtifacts.profileResource,
      LongHorizonProfessionalPolicyArtifacts.adversarialResource,
      LongHorizonProfessionalPolicyArtifacts.holdoutResource,
    ] {
      #expect(
        LongHorizonProfessionalPolicyArtifacts
          .containsBundledResource(named: name))
    }
    for obsoleteName in [
      "long-horizon-professional-profile-v1",
      "long-horizon-adversarial-suite-v1",
      "long-horizon-holdout-v1",
      "long-horizon-professional-profile-v6",
      "long-horizon-adversarial-suite-v6",
      "long-horizon-holdout-v6",
      "long-horizon-professional-profile-v7",
      "long-horizon-adversarial-suite-v7",
      "long-horizon-holdout-v7",
      "long-horizon-professional-profile-v8",
      "long-horizon-adversarial-suite-v8",
      "long-horizon-holdout-v8",
      "long-horizon-professional-profile-v9",
      "long-horizon-adversarial-suite-v9",
      "long-horizon-holdout-v9",
      "long-horizon-professional-profile-v10",
      "long-horizon-adversarial-suite-v10",
      "long-horizon-holdout-v10",
      "long-horizon-professional-profile-v11",
      "long-horizon-adversarial-suite-v11",
      "long-horizon-holdout-v11",
    ] {
      #expect(
        !LongHorizonProfessionalPolicyArtifacts
          .containsBundledResource(named: obsoleteName))
    }
    let artifacts = try LongHorizonProfessionalPolicyArtifacts.load()
    #expect(
      artifacts.profile.fingerprint
        == LongHorizonProfessionalPolicyArtifacts.expectedProfileFingerprint)
    #expect(
      artifacts.adversarial.fingerprint
        == LongHorizonProfessionalPolicyArtifacts.expectedAdversarialFingerprint)
    #expect(
      artifacts.holdout.fingerprint
        == LongHorizonProfessionalPolicyArtifacts.expectedHoldoutFingerprint)
    #expect(artifacts.adversarial.passed)
    #expect(artifacts.holdout.qualified)
  }

  @Test("Current policy resources are reduced, canonical, and fail closed")
  func currentPolicyResourcesFailClosed() throws {
    let generated = try qualifiedArtifacts()
    let profileData = try generated.profile.deterministicJSON()
    let adversarialData = try generated.adversarial.deterministicJSON()
    let holdoutData = try generated.holdout.deterministicJSON()
    try writeLongHorizonArtifactsIfRequested(
      profile: profileData,
      adversarial: adversarialData,
      holdout: holdoutData)
    let texts = try [profileData, adversarialData, holdoutData].map { data in
      try #require(String(data: data, encoding: .utf8))
    }

    for text in texts {
      #expect(!text.contains(#"\"pcm\":"#))
      #expect(!text.contains(#"\"samples\":"#))
      #expect(!text.contains(#"\"sampleData\":"#))
      #expect(!text.contains(#"\"waveform\":"#))
      #expect(!text.contains(#"\"audioData\":"#))
    }

    var packagedProfile = profileData
    packagedProfile.append(0x0A)
    _ = try LongHorizonProfessionalPolicyArtifacts(
      profileData: packagedProfile,
      adversarialData: adversarialData,
      holdoutData: holdoutData)

    var nonCanonical = Data([0x20])
    nonCanonical.append(profileData)
    #expect(throws: LongHorizonProfessionalPolicyError.nonCanonicalJSON) {
      try LongHorizonProfessionalPolicyArtifacts(
        profileData: nonCanonical,
        adversarialData: adversarialData,
        holdoutData: holdoutData)
    }

    let oldProfile = try #require(
      texts[0].replacingOccurrences(
        of: LongHorizonProfessionalPolicySchema.profileVersion,
        with: "autotechno-long-horizon-professional-profile.v0"
      )
      .data(using: .utf8))
    #expect(throws: LongHorizonProfessionalPolicyError.nonCanonicalJSON) {
      try LongHorizonProfessionalPolicyArtifacts(
        profileData: oldProfile,
        adversarialData: adversarialData,
        holdoutData: holdoutData)
    }
  }

  private func writeLongHorizonArtifactsIfRequested(
    profile: Data,
    adversarial: Data,
    holdout: Data
  ) throws {
    guard let outputDirectory = ProcessInfo.processInfo.environment[
      "AUTOTECHNO_LONG_HORIZON_RESOURCE_DIRECTORY"
    ], !outputDirectory.isEmpty else { return }
    let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true)
    try profile.write(
      to: directory.appendingPathComponent(
        "\(LongHorizonProfessionalPolicyArtifacts.profileResource).json"),
      options: .atomic)
    try adversarial.write(
      to: directory.appendingPathComponent(
        "\(LongHorizonProfessionalPolicyArtifacts.adversarialResource).json"),
      options: .atomic)
    try holdout.write(
      to: directory.appendingPathComponent(
        "\(LongHorizonProfessionalPolicyArtifacts.holdoutResource).json"),
      options: .atomic)
  }

  @Test("Runtime policy uses one exact calibrated rate and carries no PCM")
  func runtimeObservationIsReducedAndExactRate() throws {
    let artifacts = try qualifiedArtifacts()
    let source = artifacts.holdoutCorpus.observations[0]
    let observation = try LongHorizonRuntimePolicyObservation(
      calibrationObservation: source,
      sampleRate: 8_000)
    let policy = try LongHorizonProfessionalPolicy(
      profile: artifacts.profile,
      adversarial: artifacts.adversarial,
      holdout: artifacts.holdout)
    let text = try #require(String(
      data: observation.deterministicJSON(),
      encoding: .utf8))

    #expect(observation.isStructurallyComplete)
    #expect(observation.hasMinimumDecisionEvidence)
    #expect(observation.sampleRate == 8_000)
    #expect(
      observation.operatorDeltas.count
        == LongHorizonEpisodeOperator.allCases.count
          * LongHorizonSignalMetric.allCases.count)
    #expect(policy.evaluate(observation).accepted)
    #expect(!text.contains(#"\"pcm\":"#))
    #expect(!text.contains(#"\"samples\":"#))
    #expect(!text.contains(#"\"sampleData\":"#))
    #expect(!text.contains(#"\"waveform\":"#))
    #expect(observation.sourceFingerprint.count == 16)
  }

  @Test("Every failed dimension maps to one bounded future decision reason")
  func runtimeDecisionReasonsRemainIndependent() throws {
    let artifacts = try qualifiedArtifacts()
    let observation = try LongHorizonRuntimePolicyObservation(
      calibrationObservation: artifacts.holdoutCorpus.observations[0],
      sampleRate: 8_000)
    let expected: [LongHorizonTrajectoryDecisionReason] = [
      .identity, .duration, .semanticPeriodicity, .permanentPeak,
      .recoveryStarvation, .identityRecall, .dramaticDebt,
      .capabilityFatigue, .operatorConsequence, .effectFatigue,
    ]

    for (dimension, reason) in zip(
      LongHorizonPolicyFailureDimension.allCases,
      expected)
    {
      let verdict = LongHorizonPolicyVerdict(
        accepted: false,
        failedDimensions: [dimension],
        failedSemanticMetrics: [],
        failedOperatorDeltas: [],
        failedEffectFamilies: [])
      let decision = LongHorizonFutureDecisionFactory.make(
        observation: observation,
        verdict: verdict,
        policyVersion: "test-runtime-policy.v1",
        observedThroughPhraseIndex: 713,
        observedThroughBar: observation.observedBarCount,
        recoveryEligible: true)
      #expect(decision?.action == .recover)
      #expect(decision?.reasons == [reason])
      #expect(decision?.targetPhraseIndex == 714)
      #expect(decision?.targetBar == observation.observedBarCount)
    }

    let qualified = LongHorizonFutureDecisionFactory.make(
      observation: observation,
      verdict: LongHorizonPolicyVerdict(
        accepted: true,
        failedDimensions: [],
        failedSemanticMetrics: [],
        failedOperatorDeltas: [],
        failedEffectFamilies: []),
      policyVersion: "test-runtime-policy.v1",
      observedThroughPhraseIndex: 713,
      observedThroughBar: observation.observedBarCount,
      recoveryEligible: false)
    #expect(qualified?.action == .preserve)
    #expect(qualified?.reasons == [.qualified])

    let deferred = LongHorizonFutureDecisionFactory.make(
      observation: observation,
      verdict: LongHorizonPolicyVerdict(
        accepted: false,
        failedDimensions: [.effectFatigue],
        failedSemanticMetrics: [],
        failedOperatorDeltas: [],
        failedEffectFamilies: [.generatedGraph]),
      policyVersion: "test-runtime-policy.v1",
      observedThroughPhraseIndex: 713,
      observedThroughBar: observation.observedBarCount,
      recoveryEligible: false)
    #expect(deferred == nil)

    let materialReframe = LongHorizonFutureDecisionFactory.make(
      observation: observation,
      verdict: LongHorizonPolicyVerdict(
        accepted: false,
        failedDimensions: [.semanticPeriodicity, .effectFatigue],
        failedSemanticMetrics: [],
        failedOperatorDeltas: [],
        failedEffectFamilies: [.generatedGraph]),
      policyVersion: "test-runtime-policy.v1",
      observedThroughPhraseIndex: 713,
      observedThroughBar: observation.observedBarCount,
      recoveryEligible: false,
      materialReframeEligible: true)
    #expect(materialReframe?.action == .reframeMaterial)
    #expect(
      materialReframe?.reasons == [.semanticPeriodicity, .effectFatigue]
    )

    let nonMaterialDeficit = LongHorizonFutureDecisionFactory.make(
      observation: observation,
      verdict: LongHorizonPolicyVerdict(
        accepted: false,
        failedDimensions: [.permanentPeak],
        failedSemanticMetrics: [],
        failedOperatorDeltas: [],
        failedEffectFamilies: []),
      policyVersion: "test-runtime-policy.v1",
      observedThroughPhraseIndex: 713,
      observedThroughBar: observation.observedBarCount,
      recoveryEligible: false,
      materialReframeEligible: true)
    #expect(nonMaterialDeficit == nil)
  }

  @Test("Short runtime evidence is reason coded but cannot change trajectory")
  func shortRuntimeEvidenceCannotDecide() throws {
    let artifacts = try qualifiedArtifacts()
    let short = makeObservation(rootSeed: 777, observedBarCount: 1_000)
    let observation = try LongHorizonRuntimePolicyObservation(
      calibrationObservation: short,
      sampleRate: 8_000)
    let evaluator = try LongHorizonProfessionalProfileEvaluator(
      profile: artifacts.profile)
    let verdict = evaluator.evaluate(observation)

    #expect(!observation.hasMinimumDecisionEvidence)
    #expect(verdict.failedDimensions.contains(.duration))
    #expect(LongHorizonFutureDecisionFactory.make(
      observation: observation,
      verdict: verdict,
      policyVersion: "test-runtime-policy.v1",
      observedThroughPhraseIndex: 90,
      observedThroughBar: 1_000,
      recoveryEligible: true
    ) == nil)
  }
}

typealias QualifiedLongHorizonArtifacts = (
  development: LongHorizonPolicyCalibrationCorpus,
  profile: LongHorizonProfessionalProfile,
  adversarial: LongHorizonAdversarialSuiteReport,
  holdoutCorpus: LongHorizonPolicyCalibrationCorpus,
  holdout: LongHorizonHoldoutQualification
)

private let longHorizonDevelopmentSeeds: [UInt64] = [
  7, 13, 17, 42, 73, 101, 131,
]

func qualifiedArtifacts() throws -> QualifiedLongHorizonArtifacts {
  let development = try LongHorizonPolicyCalibrationCorpus(
    observations: longHorizonDevelopmentSeeds.map {
      makeObservation(rootSeed: $0)
    })
  let profile = try LongHorizonProfessionalProfile(corpus: development)
  let adversarial = try LongHorizonAdversarialSuiteReport(
    profile: profile,
    sourceObservation: development.observations[0])
  let holdoutCorpus = try LongHorizonPolicyCalibrationCorpus(
    observations: [112_358, 141_421].map { seed in
      makeObservation(rootSeed: seed, variation: 0.5)
    })
  let holdout = try LongHorizonHoldoutQualification(
    profile: profile,
    adversarial: adversarial,
    developmentCorpus: development,
    holdoutCorpus: holdoutCorpus)
  return (development, profile, adversarial, holdoutCorpus, holdout)
}

private func makeObservation(
  rootSeed: UInt64,
  observedBarCount: Int = 7_801,
  sampleRates: [Double] = [8_000, 12_000],
  variation: Double? = nil,
  overdueDebtCount: Double = 0,
  oldestDebtAgeBars: Double? = nil
) -> LongHorizonPolicyObservation {
  let offset = variation ?? Double(rootSeed % 4)
  let semantic: [LongHorizonPolicyNamedValue] = [
    .init(metric: .highTensionDwellBars, value: 16 + offset),
    .init(metric: .recoveryBarRatio, value: 0.18 + offset * 0.005),
    .init(metric: .dominantSemanticPeriodicity, value: 0.42 + offset * 0.01),
    .init(metric: .eventSignatureRepeatRatio, value: 0.66 + offset * 0.01),
    .init(metric: .matchedIdentityRecallRatio, value: 0.82 + offset * 0.01),
    .init(metric: .zeroAgeDebtRatio, value: 0),
    .init(metric: .overdueDebtCount, value: overdueDebtCount),
    .init(
      metric: .oldestDebtAgeBars,
      value: oldestDebtAgeBars ?? 80 + offset * 2),
    .init(metric: .maximumCapabilityRunBars, value: 28 + offset),
  ]
  let deltas = sampleRates.flatMap { rate in
    LongHorizonEpisodeOperator.allCases.flatMap { operatorKind in
      LongHorizonSignalMetric.allCases.map { metric in
        let operatorIndex = Double(
          LongHorizonEpisodeOperator.allCases.firstIndex(of: operatorKind) ?? 0)
        let metricIndex = Double(
          LongHorizonSignalMetric.allCases.firstIndex(of: metric) ?? 0)
        return LongHorizonPolicyOperatorDelta(
          sampleRate: rate,
          operatorKind: operatorKind,
          metric: metric,
          transitionCount: 2,
          meanDelta: operatorIndex * 0.4 + metricIndex * 0.03
            + offset * 0.01 + rate / 1_000_000)
      }
    }
  }
  let effects = LongHorizonEffectFamily.allCases.enumerated().map { index, family in
    LongHorizonPolicyEffectObservation(
      family: family,
      observedBarCount: 96,
      eligibleBarCount: 24 + index,
      activeBarCount: 12 + index,
      tailOnlyBarCount: 2,
      recoveryCount: 3,
      maximumActiveRunBars: 5 + index,
      wetBarOccupancy: Double(12 + index) / 96,
      maximumReturnToSourceDB: -12 + Double(index),
      materialWorldCount: family == .generatedGraph ? 8 : nil,
      meanEffectWorldDistance: family == .generatedGraph ? 0.18 : nil,
      maximumEffectWorldDistance: family == .generatedGraph ? 0.42 : nil)
  }
  return LongHorizonPolicyObservation(
    engineVersion: QualityQualificationContract.engineVersion,
    primaryPolicyVersion:
      LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion,
    rootSeed: rootSeed,
    semanticFingerprint: fixedPolicyHex(rootSeed &* 17),
    observedPhraseCount: 714,
    observedBarCount: observedBarCount,
    semanticValues: semantic,
    sampleRates: sampleRates,
    signalFingerprints: sampleRates.enumerated().map {
      fixedPolicyHex(rootSeed &* 31 &+ UInt64($0.offset))
    },
    signalObservationCounts: sampleRates.map { _ in 12 },
    signalOmittedPhraseCounts: sampleRates.map { _ in 702 },
    operatorDeltas: deltas,
    effects: effects)
}

private func fixedPolicyHex(_ value: UInt64) -> String {
  let raw = String(value, radix: 16)
  return String(repeating: "0", count: max(0, 16 - raw.count)) + raw
}
