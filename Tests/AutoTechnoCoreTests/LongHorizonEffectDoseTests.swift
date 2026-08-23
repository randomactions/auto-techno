import AutoTechnoCore
import Foundation
import Testing

@testable import AutoTechnoDSP

@Suite("Long-horizon effect sentences and dose evidence")
struct LongHorizonEffectDoseTests {
  @Test("Four-hour planning uses both existing sentence functions exactly")
  func planningSentencesAreCanonical() {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    var state = director.initialState()
    var capabilities = Set<String>()
    var capabilityCounts: [String: Int] = [:]
    var sentenceCount = 0

    while state.memory.totalBars < 7_800 {
      let plan = director.plan(from: state)
      #expect(
        plan.longHorizonEffectSentence
          == LongHorizonEffectSentence.resolving(
            phraseIndex: plan.phraseIndex,
            phraseKind: plan.kind,
            resolvedBars: plan.resolvedBars))
      if let sentence = plan.longHorizonEffectSentence {
        sentenceCount += 1
        capabilities.insert(sentence.capability.rawValue)
        capabilityCounts[sentence.capability.rawValue, default: 0] += 1
        #expect(
          sentence.isConsistent(
            phraseIndex: plan.phraseIndex,
            phraseKind: plan.kind,
            resolvedBars: plan.resolvedBars))
      }
      state.advancePlanning(using: plan)
    }

    #expect(sentenceCount > 0)
    #expect(
      capabilities
        == Set([
          LongHorizonEffectSentenceCapability.gatedPercussionEcho.rawValue,
          LongHorizonEffectSentenceCapability.anticipationSwell.rawValue,
        ]))
    print(
      "LONG_HORIZON_EFFECT_SENTENCES_4H total=\(sentenceCount) "
        + "gated=\(capabilityCounts[LongHorizonEffectSentenceCapability.gatedPercussionEcho.rawValue, default: 0]) "
        + "anticipation=\(capabilityCounts[LongHorizonEffectSentenceCapability.anticipationSwell.rawValue, default: 0])"
    )
  }

  @Test("Sentence provenance round-trips and rejects unsupported schema")
  func sentenceProvenanceIsStrict() throws {
    let sentence = try #require(firstPlannedSentence()?.plan.longHorizonEffectSentence)
    let encoded = try JSONEncoder().encode(sentence)
    let decoded = try JSONDecoder().decode(
      LongHorizonEffectSentence.self,
      from: encoded)
    let object = try #require(
      try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var malformed = object
    malformed["schemaIdentifier"] =
      "autotechno-long-horizon-effect-sentence.v999"
    let malformedData = try JSONSerialization.data(
      withJSONObject: malformed,
      options: [.sortedKeys])

    #expect(decoded == sentence)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        LongHorizonEffectSentence.self,
        from: malformedData)
    }
  }

  @Test("A planned sentence is bound to exact detached return evidence")
  func detachedSentenceEvidenceIsExactAndBounded() throws {
    let witness = try #require(firstPlannedSentence())
    var renderState = RenderState()
    renderState.barIndex = witness.state.memory.totalBars
    let preparedCandidate = AutonomousPhrasePreparer.prepareIfNotCancelled(
      plan: witness.plan,
      sessionSeed: witness.state.rootSeed,
      memory: witness.state.memory,
      sampleRate: 8_000,
      incomingRenderState: renderState,
      incomingGraphState: GeneratedDSPContinuationState(),
      previousGraph: nil,
      incomingQualityState: witness.state.quality,
      evaluator: AcceptingPrimaryTestEvaluator(),
      cancellationRequested: { false })
    let prepared = try #require(preparedCandidate)
    let evidence = try #require(prepared.longHorizonEffectDoseEvidence)
    let realized = try #require(evidence.realizedSentence)
    let encoded = try JSONEncoder().encode(evidence)
    let json = String(decoding: encoded, as: UTF8.self)

    #expect(evidence.isComplete)
    #expect(realized.sentence == witness.plan.longHorizonEffectSentence)
    #expect(realized.isComplete)
    #expect(evidence.bars.count == witness.plan.barCount)
    #expect(evidence.families.count == LongHorizonEffectFamily.allCases.count)
    #expect(encoded.count < 100_000)
    #expect(!json.contains("\"left\":"))
    #expect(!json.contains("\"right\":"))
    #expect(!json.contains("samples"))
  }

  @Test("Tail activity remains active until one exact clear bar")
  func tailRecoveryIsNotPremature() {
    let phrase = syntheticPhrase(
      phraseIndex: 0,
      startBar: 0,
      bars: [
        syntheticBar(
          bar: 0,
          pulseEligible: true,
          pulseSourceRMS: 0.2,
          pulseWetRMS: 0.1),
        syntheticBar(
          bar: 1,
          pulseEligible: false,
          pulseSourceRMS: 0,
          pulseWetRMS: 0.05),
        syntheticBar(
          bar: 2,
          pulseEligible: false,
          pulseSourceRMS: 0,
          pulseWetRMS: 0),
      ])
    var accumulator = LongHorizonEffectDoseAccumulator(rootSeed: 48_291)

    #expect(phrase.isComplete)
    #expect(accumulator.observe(phrase) == .accepted)
    let pulse = accumulator.report.families.first { $0.family == .pulseEcho }
    #expect(pulse?.activeBarCount == 2)
    #expect(pulse?.tailOnlyBarCount == 1)
    #expect(pulse?.activationCount == 1)
    #expect(pulse?.recoveryCount == 1)
    #expect(pulse?.maximumActiveRunBars == 2)
    #expect(pulse?.lastActiveBar == 1)
    #expect(accumulator.report.availability == .available)
    #expect(accumulator.report.qualificationStatus == "unavailable")
    #expect(
      accumulator.report.qualificationReason
        == "no-calibrated-long-horizon-policy")
  }

  @Test("Invalid causality fails closed without mutating accepted counters")
  func invalidEvidencePreservesAcceptedCounters() {
    let valid = syntheticPhrase(
      phraseIndex: 0,
      startBar: 0,
      bars: [syntheticBar(bar: 0)])
    let invalid = syntheticPhrase(
      phraseIndex: 1,
      startBar: 1,
      bars: [
        syntheticBar(
          bar: 1,
          pulseEligible: false,
          pulseSourceRMS: 0.2,
          pulseWetRMS: 0.1)
      ])
    var accumulator = LongHorizonEffectDoseAccumulator(rootSeed: 48_291)

    #expect(accumulator.observe(valid) == .accepted)
    let accepted = accumulator.report
    #expect(!invalid.isComplete)
    #expect(
      accumulator.observe(invalid)
        == .unavailable(.inconsistentEvidence))
    let failed = accumulator.report
    #expect(failed.availability == .unavailable)
    #expect(failed.unavailableReason == .inconsistentEvidence)
    #expect(failed.phraseCount == accepted.phraseCount)
    #expect(failed.barCount == accepted.barCount)
    #expect(failed.families == accepted.families)
  }

  @Test("Evidence and reports replay byte-for-byte")
  func evidenceReplayIsDeterministic() throws {
    let first = syntheticPhrase(
      phraseIndex: 0,
      startBar: 0,
      bars: [syntheticBar(bar: 0)])
    let replay = syntheticPhrase(
      phraseIndex: 0,
      startBar: 0,
      bars: [syntheticBar(bar: 0)])
    var firstAccumulator = LongHorizonEffectDoseAccumulator(rootSeed: 48_291)
    var replayAccumulator = LongHorizonEffectDoseAccumulator(rootSeed: 48_291)
    #expect(firstAccumulator.observe(first) == .accepted)
    #expect(replayAccumulator.observe(replay) == .accepted)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    #expect(first == replay)
    #expect(
      try encoder.encode(firstAccumulator.report)
        == encoder.encode(replayAccumulator.report))
  }
}

private func firstPlannedSentence() -> (
  state: AutonomousSessionState,
  plan: AutonomousPhrasePlan
)? {
  let director = AutonomousSessionDirector(rootSeed: 48_291)
  var state = director.initialState()
  while state.memory.totalBars < 7_800 {
    let plan = director.plan(from: state)
    if plan.longHorizonEffectSentence != nil {
      return (state, plan)
    }
    state.advancePlanning(using: plan)
  }
  return nil
}

private func syntheticPhrase(
  phraseIndex: Int,
  startBar: Int,
  bars: [LongHorizonEffectDoseBarEvidence]
) -> LongHorizonEffectDosePhraseEvidence {
  LongHorizonEffectDosePhraseEvidence(
    rootSeed: 48_291,
    phraseIndex: phraseIndex,
    startBar: startBar,
    phraseKind: .lock,
    planFingerprint: "0123456789abcdef",
    plannedSentence: nil,
    realizedSentence: nil,
    bars: bars)
}

private func syntheticBar(
  bar: Int,
  pulseEligible: Bool = false,
  pulseSourceRMS: Double = 0,
  pulseWetRMS: Double = 0
) -> LongHorizonEffectDoseBarEvidence {
  LongHorizonEffectDoseBarEvidence(
    bar: bar,
    expressiveGraphNodeCount: 0,
    graphInputFingerprint: "0123456789abcdef",
    graphOutputFingerprint: "0123456789abcdef",
    graphInputRMS: 1,
    graphOutputRMS: 1,
    instrumentEffectAccess: [],
    pulseEchoEligible: pulseEligible,
    pulseEchoSourceSendRMS: pulseSourceRMS,
    pulseEchoWetRMS: pulseWetRMS,
    pulseEchoPreDriveFingerprint: "123456789abcdef0",
    pulseEchoPostDriveFingerprint: "123456789abcdef0",
    percussionEchoEligible: false,
    percussionEchoSourceRMS: 0,
    percussionEchoWetRMS: 0,
    percussionEchoSourceFingerprint: "23456789abcdef01",
    percussionEchoWetFingerprint: "23456789abcdef01",
    spatialFDNEligible: false,
    spatialFDNSourceRMS: 0,
    spatialFDNWetRMS: 0,
    spatialFDNActiveWetFrameCount: 0,
    spatialFDNRenderedFrameCount: 1,
    spatialFDNSourceFingerprint: "3456789abcdef012",
    spatialFDNWetLeftFingerprint: "3456789abcdef012",
    spatialFDNWetRightFingerprint: "3456789abcdef012",
    maximumMaskingOverlap: 0,
    bindingComplete: true)
}
