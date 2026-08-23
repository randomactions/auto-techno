import AutoTechnoCore
import Foundation

/// Fixed-capacity contract for detached, realized long-horizon signal evidence.
/// Raw PCM, renderer state, and callback-owned objects never enter this value.
package enum LongHorizonSignalTrajectorySchema {
  package static let schemaVersion = 1
  package static let schemaIdentifier =
    "autotechno-long-horizon-signal-trajectory.v1"
  package static let recentPhraseCapacity = 32
  package static let recentTransitionCapacity = 32
  package static let recentEpisodeCapacity = 16
  package static let qualificationReason =
    "no-calibrated-long-horizon-policy"
}

package enum LongHorizonSignalTrajectoryAvailability: String, Codable,
  Sendable
{
  case available
  case unavailable
}

package enum LongHorizonSignalTrajectoryUnavailableReason: String, Codable,
  Sendable
{
  case noObservations = "no-observations"
  case rootSeedMismatch = "root-seed-mismatch"
  case sampleRateMismatch = "sample-rate-mismatch"
  case phraseOrderInvalid = "phrase-order-invalid"
  case barOrderInvalid = "bar-order-invalid"
  case episodeReentry = "episode-reentry"
  case inconsistentEvidence = "inconsistent-evidence"
  case counterOverflow = "counter-overflow"
}

package enum LongHorizonSignalTrajectoryObservationResult: Equatable,
  Sendable
{
  case accepted
  case unavailable(LongHorizonSignalTrajectoryUnavailableReason)
}

/// Physical dimensions remain named and non-compensable. A later calibrated
/// policy may judge each dimension, but this evidence layer never collapses
/// them into one engagement or quality score.
package enum LongHorizonSignalMetric: String, CaseIterable, Codable, Sendable {
  case integratedLoudnessLUFS = "integrated-loudness-lufs"
  case maximumMomentaryLoudnessLUFS = "maximum-momentary-loudness-lufs"
  case truePeakDBTP = "true-peak-dbtp"
  case meanBarCrestFactorDB = "mean-bar-crest-factor-db"
  case spectralCentroidHz = "spectral-centroid-hz"
  case spectralCentroidSpreadHz = "spectral-centroid-spread-hz"
  case transientDensityPerSecond = "transient-density-per-second"
  case positiveSpectralFluxMean = "positive-spectral-flux-mean"
  case lowEnergyRatio = "low-energy-ratio"
  case midEnergyRatio = "mid-energy-ratio"
  case highEnergyRatio = "high-energy-ratio"
  case maximumMaskingOverlap = "maximum-masking-overlap"
  case meanWetToDryDB = "mean-wet-to-dry-db"
  case stereoCorrelation = "stereo-correlation"
  case lowStereoCorrelation = "low-stereo-correlation"
  case movementScore = "movement-score"
}

package struct LongHorizonSignalMetricValue: Codable, Equatable, Sendable {
  package let metric: LongHorizonSignalMetric
  package let value: Double

  package init(metric: LongHorizonSignalMetric, value: Double) {
    self.metric = metric
    self.value = value
  }
}

package struct LongHorizonRealizedSignalVector: Codable, Equatable, Sendable {
  package let integratedLoudnessLUFS: Double
  package let maximumMomentaryLoudnessLUFS: Double
  package let truePeakDBTP: Double
  package let meanBarCrestFactorDB: Double
  package let spectralCentroidHz: Double
  package let spectralCentroidSpreadHz: Double
  package let transientDensityPerSecond: Double
  package let positiveSpectralFluxMean: Double
  package let lowEnergyRatio: Double
  package let midEnergyRatio: Double
  package let highEnergyRatio: Double
  package let maximumMaskingOverlap: Double
  package let meanWetToDryDB: Double?
  package let stereoCorrelation: Double
  package let lowStereoCorrelation: Double
  package let movementScore: Double

  package init(
    integratedLoudnessLUFS: Double,
    maximumMomentaryLoudnessLUFS: Double,
    truePeakDBTP: Double,
    meanBarCrestFactorDB: Double,
    spectralCentroidHz: Double,
    spectralCentroidSpreadHz: Double,
    transientDensityPerSecond: Double,
    positiveSpectralFluxMean: Double,
    lowEnergyRatio: Double,
    midEnergyRatio: Double,
    highEnergyRatio: Double,
    maximumMaskingOverlap: Double,
    meanWetToDryDB: Double?,
    stereoCorrelation: Double,
    lowStereoCorrelation: Double,
    movementScore: Double
  ) {
    self.integratedLoudnessLUFS = integratedLoudnessLUFS
    self.maximumMomentaryLoudnessLUFS = maximumMomentaryLoudnessLUFS
    self.truePeakDBTP = truePeakDBTP
    self.meanBarCrestFactorDB = meanBarCrestFactorDB
    self.spectralCentroidHz = spectralCentroidHz
    self.spectralCentroidSpreadHz = spectralCentroidSpreadHz
    self.transientDensityPerSecond = transientDensityPerSecond
    self.positiveSpectralFluxMean = positiveSpectralFluxMean
    self.lowEnergyRatio = lowEnergyRatio
    self.midEnergyRatio = midEnergyRatio
    self.highEnergyRatio = highEnergyRatio
    self.maximumMaskingOverlap = maximumMaskingOverlap
    self.meanWetToDryDB = meanWetToDryDB
    self.stereoCorrelation = stereoCorrelation
    self.lowStereoCorrelation = lowStereoCorrelation
    self.movementScore = movementScore
  }

  package var metricValues: [LongHorizonSignalMetricValue] {
    LongHorizonSignalMetric.allCases.compactMap { metric in
      value(for: metric).map {
        LongHorizonSignalMetricValue(metric: metric, value: $0)
      }
    }
  }

  package func value(for metric: LongHorizonSignalMetric) -> Double? {
    switch metric {
    case .integratedLoudnessLUFS: integratedLoudnessLUFS
    case .maximumMomentaryLoudnessLUFS: maximumMomentaryLoudnessLUFS
    case .truePeakDBTP: truePeakDBTP
    case .meanBarCrestFactorDB: meanBarCrestFactorDB
    case .spectralCentroidHz: spectralCentroidHz
    case .spectralCentroidSpreadHz: spectralCentroidSpreadHz
    case .transientDensityPerSecond: transientDensityPerSecond
    case .positiveSpectralFluxMean: positiveSpectralFluxMean
    case .lowEnergyRatio: lowEnergyRatio
    case .midEnergyRatio: midEnergyRatio
    case .highEnergyRatio: highEnergyRatio
    case .maximumMaskingOverlap: maximumMaskingOverlap
    case .meanWetToDryDB: meanWetToDryDB
    case .stereoCorrelation: stereoCorrelation
    case .lowStereoCorrelation: lowStereoCorrelation
    case .movementScore: movementScore
    }
  }

  package var isComplete: Bool {
    let required = metricValues.filter { $0.metric != .meanWetToDryDB }
    let energySum = lowEnergyRatio + midEnergyRatio + highEnergyRatio
    return required.count == LongHorizonSignalMetric.allCases.count - 1
      && required.allSatisfy { $0.value.isFinite }
      && meanWetToDryDB.map { $0.isFinite && (-240...120).contains($0) } ?? true
      && (-200...24).contains(integratedLoudnessLUFS)
      && (-200...24).contains(maximumMomentaryLoudnessLUFS)
      && (-200...24).contains(truePeakDBTP)
      && (-240...120).contains(meanBarCrestFactorDB)
      && (0...(QualityQualificationContract.maximumSupportedSampleRate / 2))
        .contains(spectralCentroidHz)
      && (0...QualityQualificationContract.maximumSupportedSampleRate)
        .contains(spectralCentroidSpreadHz)
      && (0...30).contains(transientDensityPerSecond)
      && positiveSpectralFluxMean >= 0
      && (0...1).contains(lowEnergyRatio)
      && (0...1).contains(midEnergyRatio)
      && (0...1).contains(highEnergyRatio)
      && abs(energySum - 1) <= 0.000_001
      && (0...1).contains(maximumMaskingOverlap)
      && (-1...1).contains(stereoCorrelation)
      && (-1...1).contains(lowStereoCorrelation)
      && (0...1).contains(movementScore)
  }
}

package struct LongHorizonSignalBarEvidence: Codable, Equatable, Sendable {
  package let bar: Int
  package let loudnessLUFS: Double
  package let spectralCentroidHz: Double
  package let transientDensityPerSecond: Double
  package let crestFactorDB: Double
  package let maximumMaskingOverlap: Double
  package let wetToDryDB: Double?
  package let graphOutputToInputDB: Double?
  package let finite: Bool

  package init(
    bar: Int,
    loudnessLUFS: Double,
    spectralCentroidHz: Double,
    transientDensityPerSecond: Double,
    crestFactorDB: Double,
    maximumMaskingOverlap: Double,
    wetToDryDB: Double?,
    graphOutputToInputDB: Double?,
    finite: Bool
  ) {
    self.bar = bar
    self.loudnessLUFS = loudnessLUFS
    self.spectralCentroidHz = spectralCentroidHz
    self.transientDensityPerSecond = transientDensityPerSecond
    self.crestFactorDB = crestFactorDB
    self.maximumMaskingOverlap = maximumMaskingOverlap
    self.wetToDryDB = wetToDryDB
    self.graphOutputToInputDB = graphOutputToInputDB
    self.finite = finite
  }

  package var isComplete: Bool {
    bar >= 0 && finite
      && [
        loudnessLUFS, spectralCentroidHz, transientDensityPerSecond,
        crestFactorDB, maximumMaskingOverlap,
      ].allSatisfy(\.isFinite)
      && (-200...24).contains(loudnessLUFS)
      && (0...(QualityQualificationContract.maximumSupportedSampleRate / 2))
        .contains(spectralCentroidHz)
      && (0...30).contains(transientDensityPerSecond)
      && (-240...120).contains(crestFactorDB)
      && (0...1).contains(maximumMaskingOverlap)
      && wetToDryDB.map { $0.isFinite && (-240...120).contains($0) } ?? true
      && graphOutputToInputDB.map {
        $0.isFinite && (-240...120).contains($0)
      } ?? true
  }
}

/// Exact detached phrase observation. The semantic target and realized vector
/// remain separate so a declaration cannot pass for an audible consequence.
package struct LongHorizonSignalPhraseEvidence: Codable, Equatable, Sendable {
  package let schemaVersion: Int
  package let schemaIdentifier: String
  package let rootSeed: UInt64
  package let phraseIndex: Int
  package let startBar: Int
  package let barCount: Int
  package let phraseKind: AutonomousPhraseKind
  package let coordination: LongHorizonEnergyCoordination
  package let sampleRate: Double
  package let planFingerprint: String
  package let candidateEvidenceFingerprint: String
  package let pcmFingerprint: String
  package let hardGatesPassed: Bool
  package let signal: LongHorizonRealizedSignalVector
  package let bars: [LongHorizonSignalBarEvidence]

  package init(
    rootSeed: UInt64,
    phraseIndex: Int,
    startBar: Int,
    phraseKind: AutonomousPhraseKind,
    coordination: LongHorizonEnergyCoordination,
    sampleRate: Double,
    planFingerprint: String,
    candidateEvidenceFingerprint: String,
    pcmFingerprint: String,
    hardGatesPassed: Bool,
    signal: LongHorizonRealizedSignalVector,
    bars: [LongHorizonSignalBarEvidence]
  ) {
    schemaVersion = LongHorizonSignalTrajectorySchema.schemaVersion
    schemaIdentifier = LongHorizonSignalTrajectorySchema.schemaIdentifier
    self.rootSeed = rootSeed
    self.phraseIndex = phraseIndex
    self.startBar = startBar
    barCount = bars.count
    self.phraseKind = phraseKind
    self.coordination = coordination
    self.sampleRate = sampleRate
    self.planFingerprint = planFingerprint
    self.candidateEvidenceFingerprint = candidateEvidenceFingerprint
    self.pcmFingerprint = pcmFingerprint
    self.hardGatesPassed = hardGatesPassed
    self.signal = signal
    self.bars = bars
  }

  package static func make(
    prepared: PreparedAutonomousPhrase
  ) -> LongHorizonSignalPhraseEvidence? {
    let plan = prepared.plan
    let vector = prepared.selectedCandidateEvidence
    let fullMix = vector.fullMix
    guard vector.isComplete, prepared.commitEligible,
      vector.planFingerprint == AutonomousTypedFingerprint.plan(plan),
      fullMix.sampleHash == prepared.audioPreflight.quality.sampleHash,
      fullMix.bars.count == plan.barCount,
      let dose = prepared.longHorizonEffectDoseEvidence,
      dose.isComplete, dose.bars.count == fullMix.bars.count
    else {
      return nil
    }

    var bars: [LongHorizonSignalBarEvidence] = []
    bars.reserveCapacity(fullMix.bars.count)
    for index in fullMix.bars.indices {
      let full = fullMix.bars[index]
      let effect = dose.bars[index]
      let expectedBar = plan.startBar.addingReportingOverflow(index)
      guard !expectedBar.overflow, full.bar == expectedBar.partialValue,
        effect.bar == full.bar
      else {
        return nil
      }
      let bar = LongHorizonSignalBarEvidence(
        bar: full.bar,
        loudnessLUFS: full.loudness,
        spectralCentroidHz: full.spectralCentroid,
        transientDensityPerSecond: full.transientDensity,
        crestFactorDB: Self.decibels(amplitude: full.crestFactor),
        maximumMaskingOverlap: effect.maximumMaskingOverlap,
        wetToDryDB: effect.combinedWetToDryDB,
        graphOutputToInputDB: effect.graphOutputToInputDB,
        finite: full.finite && effect.isComplete
      )
      guard bar.isComplete else { return nil }
      bars.append(bar)
    }

    let musical = prepared.audioPreflight.quality.musical
    let crestValues = bars.map(\.crestFactorDB)
    let transientValues = bars.map(\.transientDensityPerSecond)
    let wetValues = bars.compactMap(\.wetToDryDB)
    let signal = LongHorizonRealizedSignalVector(
      integratedLoudnessLUFS: fullMix.integratedLoudness,
      maximumMomentaryLoudnessLUFS: fullMix.maximumMomentaryLoudness,
      truePeakDBTP: fullMix.truePeakDBTP,
      meanBarCrestFactorDB: Self.mean(crestValues),
      spectralCentroidHz: musical.spectralCentroid,
      spectralCentroidSpreadHz:
        musical.perceptualEvidence.spectralCentroidSpreadHz,
      transientDensityPerSecond: Self.mean(transientValues),
      positiveSpectralFluxMean:
        musical.perceptualEvidence.positiveSpectralFluxMean,
      lowEnergyRatio: musical.lowEnergy,
      midEnergyRatio: musical.midEnergy,
      highEnergyRatio: musical.highEnergy,
      maximumMaskingOverlap: bars.map(\.maximumMaskingOverlap).max() ?? 0,
      meanWetToDryDB: wetValues.isEmpty ? nil : Self.mean(wetValues),
      stereoCorrelation: fullMix.stereoCorrelation,
      lowStereoCorrelation: fullMix.lowStereoCorrelation,
      movementScore: fullMix.movementScore
    )
    let evidence = LongHorizonSignalPhraseEvidence(
      rootSeed: prepared.graph.sessionSeed,
      phraseIndex: plan.phraseIndex,
      startBar: plan.startBar,
      phraseKind: plan.kind,
      coordination: plan.longHorizonEnergyCoordination,
      sampleRate: vector.routeContinuation.sampleRate,
      planFingerprint: vector.planFingerprint,
      candidateEvidenceFingerprint: prepared.candidateEvaluationFingerprint,
      pcmFingerprint: fullMix.sampleHash,
      hardGatesPassed: prepared.playbackHardGatesPassed,
      signal: signal,
      bars: bars
    )
    return evidence.isComplete ? evidence : nil
  }

  package var isComplete: Bool {
    let endBar = startBar.addingReportingOverflow(barCount)
    let exactBars = bars.indices.allSatisfy { index in
      let expected = startBar.addingReportingOverflow(index)
      return !expected.overflow && bars[index].bar == expected.partialValue
        && bars[index].isComplete
    }
    let coordinateIsBound =
      coordination.phraseIndex == phraseIndex
      && coordination.startBar == startBar
      && coordination.phraseKind == phraseKind
    let episodeIsCanonical: Bool
    switch (coordination.episodeID, coordination.operatorKind) {
    case (nil, nil):
      episodeIsCanonical =
        coordination.reason == .conservativeFallback
        && coordination.target.isNeutral
    case (.some, let operatorKind?):
      switch coordination.reason {
      case .conservativeFallback:
        episodeIsCanonical = false
      case .protectedRareEvent:
        episodeIsCanonical = coordination.target.isNeutral
      case .episodeProgression, .episodeFulfillment:
        episodeIsCanonical =
          coordination.target
          == LongHorizonContinuationState.target(for: operatorKind)
      }
    default:
      episodeIsCanonical = false
    }
    return schemaVersion == LongHorizonSignalTrajectorySchema.schemaVersion
      && schemaIdentifier == LongHorizonSignalTrajectorySchema.schemaIdentifier
      && phraseIndex >= 0 && startBar >= 0
      && (1...AutonomousCandidateEvaluationVector.maximumBarCount)
        .contains(barCount)
      && !endBar.overflow && barCount == bars.count && exactBars && coordinateIsBound
      && episodeIsCanonical && sampleRate.isFinite
      && sampleRate >= QualityQualificationContract.minimumSupportedSampleRate
      && sampleRate <= QualityQualificationContract.maximumSupportedSampleRate
      && Self.isFingerprint(planFingerprint)
      && Self.isFingerprint(candidateEvidenceFingerprint)
      && Self.isFingerprint(pcmFingerprint)
      && hardGatesPassed && signal.isComplete
  }

  private static func mean(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
  }

  private static func decibels(amplitude: Double) -> Double {
    guard amplitude.isFinite, amplitude > 0 else { return -240 }
    return max(-240, min(120, 20 * log10(amplitude)))
  }

  private static func isFingerprint(_ value: String) -> Bool {
    value.count == 16
      && value.utf8.allSatisfy { byte in
        (48...57).contains(byte) || (97...102).contains(byte)
      }
  }
}

package struct LongHorizonSignalTransitionEvidence: Codable, Equatable,
  Sendable
{
  package let fromPhraseIndex: Int
  package let toPhraseIndex: Int
  package let fromEndBar: Int
  package let toStartBar: Int
  package let omittedPhraseCount: Int
  package let omittedBarCount: Int
  package let fromEpisodeID: UInt64?
  package let toEpisodeID: UInt64?
  package let operatorKind: LongHorizonEpisodeOperator?
  package let target: LongHorizonEnergyTarget
  package let sameEpisode: Bool
  package let metricDeltas: [LongHorizonSignalMetricValue]

  fileprivate init(
    from: LongHorizonSignalPhraseEvidence,
    to: LongHorizonSignalPhraseEvidence
  ) {
    fromPhraseIndex = from.phraseIndex
    toPhraseIndex = to.phraseIndex
    fromEndBar = from.startBar + from.barCount
    toStartBar = to.startBar
    omittedPhraseCount = max(0, to.phraseIndex - from.phraseIndex - 1)
    omittedBarCount = max(0, to.startBar - fromEndBar)
    fromEpisodeID = from.coordination.episodeID
    toEpisodeID = to.coordination.episodeID
    operatorKind = to.coordination.operatorKind
    target = to.coordination.target
    sameEpisode =
      from.coordination.episodeID != nil
      && from.coordination.episodeID == to.coordination.episodeID
    metricDeltas = LongHorizonSignalMetric.allCases.compactMap { metric in
      guard let start = from.signal.value(for: metric),
        let end = to.signal.value(for: metric)
      else {
        return nil
      }
      return LongHorizonSignalMetricValue(metric: metric, value: end - start)
    }
  }
}

package struct LongHorizonSignalMetricSummary: Codable, Equatable, Sendable {
  package let metric: LongHorizonSignalMetric
  package let observationCount: Int
  package let minimum: Double
  package let maximum: Double
  package let mean: Double
}

package struct LongHorizonSignalEpisodeSummary: Codable, Equatable, Sendable {
  package let episodeID: UInt64
  package let operatorKind: LongHorizonEpisodeOperator
  package let firstPhraseIndex: Int
  package let lastPhraseIndex: Int
  package let firstBar: Int
  package let lastEndBar: Int
  package let observationCount: Int
  package let metrics: [LongHorizonSignalMetricSummary]
}

package struct LongHorizonSignalOperatorCount: Codable, Equatable, Sendable {
  package let operatorKind: LongHorizonEpisodeOperator
  package let observationCount: Int
}

package struct LongHorizonSignalOperatorTransitionSummary: Codable, Equatable,
  Sendable
{
  package let operatorKind: LongHorizonEpisodeOperator
  package let transitionCount: Int
  package let metricDeltas: [LongHorizonSignalMetricSummary]
}

package struct LongHorizonSignalTrajectoryReport: Codable, Equatable,
  Sendable
{
  package let schemaVersion: Int
  package let schemaIdentifier: String
  package let availability: LongHorizonSignalTrajectoryAvailability
  package let unavailableReason: LongHorizonSignalTrajectoryUnavailableReason?
  package let qualificationStatus: String
  package let qualificationReason: String
  package let rootSeed: UInt64
  package let sampleRate: Double
  package let observationCount: Int
  package let renderedBarCount: Int
  package let omittedPhraseCount: Int
  package let omittedBarCount: Int
  package let operatorCounts: [LongHorizonSignalOperatorCount]
  package let operatorTransitions: [LongHorizonSignalOperatorTransitionSummary]
  package let metrics: [LongHorizonSignalMetricSummary]
  package let recentPhrases: [LongHorizonSignalPhraseEvidence]
  package let recentTransitions: [LongHorizonSignalTransitionEvidence]
  package let recentEpisodes: [LongHorizonSignalEpisodeSummary]
  package let trajectoryFingerprint: String
}

/// Fixed-capacity checkpoint accumulator. Phrase and bar gaps are explicit so
/// representative episode-boundary renders cannot masquerade as contiguous
/// PCM. Invalid observations make the report unavailable without mutating any
/// previously accepted counts or summaries.
package struct LongHorizonSignalTrajectoryAccumulator: Sendable {
  private struct MetricState: Sendable {
    var count = 0
    var sum = 0.0
    var minimum: Double?
    var maximum: Double?

    mutating func observe(_ value: Double) {
      count += 1
      sum += value
      minimum = min(minimum ?? value, value)
      maximum = max(maximum ?? value, value)
    }

    func canObserve(_ value: Double) -> Bool {
      !count.addingReportingOverflow(1).overflow
        && (sum + value).isFinite
    }

    func summary(_ metric: LongHorizonSignalMetric)
      -> LongHorizonSignalMetricSummary?
    {
      guard count > 0, let minimum, let maximum else { return nil }
      return LongHorizonSignalMetricSummary(
        metric: metric,
        observationCount: count,
        minimum: minimum,
        maximum: maximum,
        mean: sum / Double(count)
      )
    }
  }

  private struct EpisodeState: Sendable {
    let id: UInt64
    let operatorKind: LongHorizonEpisodeOperator
    let firstPhraseIndex: Int
    var lastPhraseIndex: Int
    let firstBar: Int
    var lastEndBar: Int
    var observationCount = 0
    var metrics = LongHorizonSignalMetric.allCases.map { _ in MetricState() }

    mutating func observe(_ evidence: LongHorizonSignalPhraseEvidence) {
      lastPhraseIndex = evidence.phraseIndex
      lastEndBar = evidence.startBar + evidence.barCount
      observationCount += 1
      for (index, metric) in LongHorizonSignalMetric.allCases.enumerated() {
        if let value = evidence.signal.value(for: metric) {
          metrics[index].observe(value)
        }
      }
    }

    var summary: LongHorizonSignalEpisodeSummary {
      LongHorizonSignalEpisodeSummary(
        episodeID: id,
        operatorKind: operatorKind,
        firstPhraseIndex: firstPhraseIndex,
        lastPhraseIndex: lastPhraseIndex,
        firstBar: firstBar,
        lastEndBar: lastEndBar,
        observationCount: observationCount,
        metrics: zip(LongHorizonSignalMetric.allCases, metrics).compactMap {
          $1.summary($0)
        }
      )
    }
  }

  private let rootSeed: UInt64
  private let sampleRate: Double
  private var observationCount = 0
  private var renderedBarCount = 0
  private var omittedPhraseCount = 0
  private var omittedBarCount = 0
  private var operatorCounts = LongHorizonEpisodeOperator.allCases.map { _ in 0 }
  private var operatorTransitionCounts = LongHorizonEpisodeOperator.allCases.map { _ in 0 }
  private var operatorTransitionMetrics = LongHorizonEpisodeOperator.allCases.map { _ in
    LongHorizonSignalMetric.allCases.map { _ in MetricState() }
  }
  private var metrics = LongHorizonSignalMetric.allCases.map { _ in MetricState() }
  private var lastPhrase: LongHorizonSignalPhraseEvidence?
  private var recentPhrases: [LongHorizonSignalPhraseEvidence] = []
  private var recentTransitions: [LongHorizonSignalTransitionEvidence] = []
  private var completedEpisodeIDs: [UInt64] = []
  private var recentEpisodes: [LongHorizonSignalEpisodeSummary] = []
  private var currentEpisode: EpisodeState?
  private var trajectoryHasher = LongHorizonSignalHasher()
  private var unavailableReason: LongHorizonSignalTrajectoryUnavailableReason?

  package init(rootSeed: UInt64, sampleRate: Double) {
    precondition(sampleRate.isFinite)
    precondition(
      sampleRate >= QualityQualificationContract.minimumSupportedSampleRate
        && sampleRate <= QualityQualificationContract.maximumSupportedSampleRate
    )
    self.rootSeed = rootSeed
    self.sampleRate = sampleRate
  }

  package mutating func observe(
    _ evidence: LongHorizonSignalPhraseEvidence
  ) -> LongHorizonSignalTrajectoryObservationResult {
    if let unavailableReason {
      return .unavailable(unavailableReason)
    }
    let reason = validationFailure(for: evidence)
    if let reason {
      unavailableReason = reason
      return .unavailable(reason)
    }
    var candidate = self
    candidate.apply(evidence)
    self = candidate
    return .accepted
  }

  package var report: LongHorizonSignalTrajectoryReport {
    let reason = unavailableReason ?? (observationCount == 0 ? .noObservations : nil)
    var episodes = recentEpisodes
    if let currentEpisode { episodes.append(currentEpisode.summary) }
    if episodes.count > LongHorizonSignalTrajectorySchema.recentEpisodeCapacity {
      episodes.removeFirst(
        episodes.count - LongHorizonSignalTrajectorySchema.recentEpisodeCapacity
      )
    }
    return LongHorizonSignalTrajectoryReport(
      schemaVersion: LongHorizonSignalTrajectorySchema.schemaVersion,
      schemaIdentifier: LongHorizonSignalTrajectorySchema.schemaIdentifier,
      availability: reason == nil ? .available : .unavailable,
      unavailableReason: reason,
      qualificationStatus: "unavailable",
      qualificationReason: LongHorizonSignalTrajectorySchema.qualificationReason,
      rootSeed: rootSeed,
      sampleRate: sampleRate,
      observationCount: observationCount,
      renderedBarCount: renderedBarCount,
      omittedPhraseCount: omittedPhraseCount,
      omittedBarCount: omittedBarCount,
      operatorCounts: zip(LongHorizonEpisodeOperator.allCases, operatorCounts)
        .map {
          LongHorizonSignalOperatorCount(
            operatorKind: $0,
            observationCount: $1
          )
        },
      operatorTransitions: LongHorizonEpisodeOperator.allCases.enumerated().map {
        index, operatorKind in
        LongHorizonSignalOperatorTransitionSummary(
          operatorKind: operatorKind,
          transitionCount: operatorTransitionCounts[index],
          metricDeltas: zip(
            LongHorizonSignalMetric.allCases,
            operatorTransitionMetrics[index]
          ).compactMap { $1.summary($0) }
        )
      },
      metrics: zip(LongHorizonSignalMetric.allCases, metrics).compactMap {
        $1.summary($0)
      },
      recentPhrases: recentPhrases,
      recentTransitions: recentTransitions,
      recentEpisodes: episodes,
      trajectoryFingerprint: trajectoryHasher.fingerprint
    )
  }

  private func validationFailure(
    for evidence: LongHorizonSignalPhraseEvidence
  ) -> LongHorizonSignalTrajectoryUnavailableReason? {
    guard evidence.isComplete else { return .inconsistentEvidence }
    guard evidence.rootSeed == rootSeed else { return .rootSeedMismatch }
    guard evidence.sampleRate == sampleRate else { return .sampleRateMismatch }
    if let lastPhrase {
      guard evidence.phraseIndex > lastPhrase.phraseIndex else {
        return .phraseOrderInvalid
      }
      let lastEnd = lastPhrase.startBar.addingReportingOverflow(lastPhrase.barCount)
      guard !lastEnd.overflow, evidence.startBar >= lastEnd.partialValue else {
        return .barOrderInvalid
      }
    }
    if let episodeID = evidence.coordination.episodeID,
      currentEpisode?.id != episodeID,
      completedEpisodeIDs.contains(episodeID)
    {
      return .episodeReentry
    }
    if let currentEpisode,
      currentEpisode.id == evidence.coordination.episodeID,
      currentEpisode.operatorKind != evidence.coordination.operatorKind
    {
      return .inconsistentEvidence
    }
    let phraseGap =
      lastPhrase.map {
        evidence.phraseIndex - $0.phraseIndex - 1
      } ?? 0
    let barGap =
      lastPhrase.map {
        evidence.startBar - ($0.startBar + $0.barCount)
      } ?? 0
    let additions = [
      (observationCount, 1),
      (renderedBarCount, evidence.barCount),
      (omittedPhraseCount, phraseGap),
      (omittedBarCount, barGap),
    ]
    guard additions.allSatisfy({ !$0.0.addingReportingOverflow($0.1).overflow })
    else {
      return .counterOverflow
    }
    if let operatorKind = evidence.coordination.operatorKind,
      let index = LongHorizonEpisodeOperator.allCases.firstIndex(of: operatorKind),
      operatorCounts[index].addingReportingOverflow(1).overflow
    {
      return .counterOverflow
    }
    if let lastPhrase,
      let operatorKind = evidence.coordination.operatorKind,
      let operatorIndex = LongHorizonEpisodeOperator.allCases.firstIndex(of: operatorKind)
    {
      let transition = LongHorizonSignalTransitionEvidence(
        from: lastPhrase,
        to: evidence
      )
      guard
        !operatorTransitionCounts[operatorIndex]
          .addingReportingOverflow(1).overflow
      else { return .counterOverflow }
      for delta in transition.metricDeltas {
        guard
          let metricIndex = LongHorizonSignalMetric.allCases.firstIndex(of: delta.metric),
          operatorTransitionMetrics[operatorIndex][metricIndex]
            .canObserve(delta.value)
        else { return .counterOverflow }
      }
    }
    for (index, metric) in LongHorizonSignalMetric.allCases.enumerated() {
      if let value = evidence.signal.value(for: metric),
        !metrics[index].canObserve(value)
      {
        return .counterOverflow
      }
    }
    if let currentEpisode,
      currentEpisode.id == evidence.coordination.episodeID
    {
      guard !currentEpisode.observationCount.addingReportingOverflow(1).overflow
      else { return .counterOverflow }
      for (index, metric) in LongHorizonSignalMetric.allCases.enumerated() {
        if let value = evidence.signal.value(for: metric),
          !currentEpisode.metrics[index].canObserve(value)
        {
          return .counterOverflow
        }
      }
    }
    return nil
  }

  private mutating func apply(_ evidence: LongHorizonSignalPhraseEvidence) {
    if let lastPhrase {
      let transition = LongHorizonSignalTransitionEvidence(
        from: lastPhrase,
        to: evidence
      )
      if let operatorKind = transition.operatorKind,
        let operatorIndex = LongHorizonEpisodeOperator.allCases.firstIndex(of: operatorKind)
      {
        operatorTransitionCounts[operatorIndex] += 1
        for delta in transition.metricDeltas {
          if let metricIndex = LongHorizonSignalMetric.allCases.firstIndex(of: delta.metric) {
            operatorTransitionMetrics[operatorIndex][metricIndex]
              .observe(delta.value)
          }
        }
      }
      recentTransitions.append(transition)
      omittedPhraseCount += transition.omittedPhraseCount
      omittedBarCount += transition.omittedBarCount
      trimRecentTransitions()
    }
    observationCount += 1
    renderedBarCount += evidence.barCount
    recentPhrases.append(evidence)
    if recentPhrases.count > LongHorizonSignalTrajectorySchema.recentPhraseCapacity {
      recentPhrases.removeFirst(
        recentPhrases.count - LongHorizonSignalTrajectorySchema.recentPhraseCapacity
      )
    }
    for (index, metric) in LongHorizonSignalMetric.allCases.enumerated() {
      if let value = evidence.signal.value(for: metric) {
        metrics[index].observe(value)
      }
    }
    if let operatorKind = evidence.coordination.operatorKind,
      let index = LongHorizonEpisodeOperator.allCases.firstIndex(of: operatorKind)
    {
      operatorCounts[index] += 1
    }
    updateEpisode(with: evidence)
    combine(evidence, into: &trajectoryHasher)
    lastPhrase = evidence
  }

  private mutating func updateEpisode(
    with evidence: LongHorizonSignalPhraseEvidence
  ) {
    guard let episodeID = evidence.coordination.episodeID,
      let operatorKind = evidence.coordination.operatorKind
    else {
      finalizeCurrentEpisode()
      return
    }
    if currentEpisode?.id != episodeID {
      finalizeCurrentEpisode()
      currentEpisode = EpisodeState(
        id: episodeID,
        operatorKind: operatorKind,
        firstPhraseIndex: evidence.phraseIndex,
        lastPhraseIndex: evidence.phraseIndex,
        firstBar: evidence.startBar,
        lastEndBar: evidence.startBar + evidence.barCount
      )
    }
    currentEpisode?.observe(evidence)
  }

  private mutating func finalizeCurrentEpisode() {
    guard let currentEpisode else { return }
    recentEpisodes.append(currentEpisode.summary)
    completedEpisodeIDs.append(currentEpisode.id)
    if recentEpisodes.count > LongHorizonSignalTrajectorySchema.recentEpisodeCapacity {
      recentEpisodes.removeFirst(
        recentEpisodes.count - LongHorizonSignalTrajectorySchema.recentEpisodeCapacity
      )
    }
    if completedEpisodeIDs.count > LongHorizonSignalTrajectorySchema.recentEpisodeCapacity {
      completedEpisodeIDs.removeFirst(
        completedEpisodeIDs.count - LongHorizonSignalTrajectorySchema.recentEpisodeCapacity
      )
    }
    self.currentEpisode = nil
  }

  private mutating func trimRecentTransitions() {
    if recentTransitions.count
      > LongHorizonSignalTrajectorySchema.recentTransitionCapacity
    {
      recentTransitions.removeFirst(
        recentTransitions.count
          - LongHorizonSignalTrajectorySchema.recentTransitionCapacity
      )
    }
  }

  private func combine(
    _ evidence: LongHorizonSignalPhraseEvidence,
    into hasher: inout LongHorizonSignalHasher
  ) {
    hasher.combine("phrase")
    hasher.combine(evidence.phraseIndex)
    hasher.combine(evidence.startBar)
    hasher.combine(evidence.barCount)
    hasher.combine(evidence.phraseKind.rawValue)
    hasher.combine(evidence.coordination.episodeID ?? 0)
    hasher.combine(evidence.coordination.operatorKind?.rawValue ?? "none")
    hasher.combine(evidence.planFingerprint)
    hasher.combine(evidence.candidateEvidenceFingerprint)
    hasher.combine(evidence.pcmFingerprint)
    for value in evidence.signal.metricValues {
      hasher.combine(value.metric.rawValue)
      hasher.combine(value.value)
    }
  }
}

private struct LongHorizonSignalHasher: Sendable {
  private var value: UInt64 = 0xcbf2_9ce4_8422_2325

  var fingerprint: String {
    let raw = String(value, radix: 16)
    return String(repeating: "0", count: 16 - raw.count) + raw
  }

  mutating func combine(_ value: String) {
    for byte in value.utf8 { combine(byte) }
    combine(0xff)
  }

  mutating func combine(_ value: Int) {
    combine(UInt64(bitPattern: Int64(value)))
  }

  mutating func combine(_ value: UInt64) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      for byte in bytes { combine(byte) }
    }
  }

  mutating func combine(_ value: Double) {
    combine(value.bitPattern)
  }

  private mutating func combine(_ byte: UInt8) {
    value ^= UInt64(byte)
    value = value &* 0x0000_0100_0000_01b3
  }
}

extension PreparedAutonomousPhrase {
  package var longHorizonSignalTrajectoryEvidence: LongHorizonSignalPhraseEvidence? {
    LongHorizonSignalPhraseEvidence.make(prepared: self)
  }
}
