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
  // Native Debug's value-heavy fixture exceeds the cooperative worker stack.
  // Isolate only test setup/assertions; the production preparation is unchanged.
  @MainActor
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

  @Test("Source-only pulse bars retain truthful activity and require eligibility")
  func sourceOnlyPulseCausality() {
    let source = syntheticBar(bar: 0, pulseEligible: true, pulseSourceRMS: 0.2)
    let tail = syntheticBar(bar: 1, pulseWetRMS: 0.05)
    let clear = syntheticBar(bar: 2)
    #expect(source.isComplete)
    #expect(!source.pulseEchoActive && !source.pulseEchoTailOnly)
    #expect(source.combinedWetRMS == 0 && source.combinedWetToDryDB == nil)
    #expect(!syntheticBar(bar: 0, pulseSourceRMS: 0.2).isComplete)
    #expect(!syntheticBar(bar: 0, pulseSourceRMS: 0.2, pulseWetRMS: 0.1).isComplete)
    #expect(!syntheticBar(bar: 0, pulseEligible: true, pulseSourceRMS: .nan).isComplete)
    var accumulator = LongHorizonEffectDoseAccumulator(rootSeed: 48_291)
    #expect(accumulator.observe(syntheticPhrase(phraseIndex: 0, startBar: 0,
      bars: [source, tail, clear])) == .accepted)
    let pulse = accumulator.report.families.first { $0.family == .pulseEcho }
    #expect(pulse?.eligibleBarCount == 1)
    #expect(pulse?.activeBarCount == 1)
    #expect(pulse?.tailOnlyBarCount == 1)
    #expect(pulse?.maximumActiveRunBars == 1)
    #expect(pulse?.recoveryCount == 1)
    #expect(accumulator.report.qualificationStatus == "unavailable")
  }

  @Test("Historical effect-dose interpretation cannot advance current state")
  func staleEffectInterpretationRefuses() throws {
    let current = syntheticPhrase(phraseIndex: 0, startBar: 0,
      bars: [syntheticBar(bar: 0)])
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
    object["schemaVersion"] = 2
    object["schemaIdentifier"] = "autotechno-long-horizon-effect-dose.v2"
    let stale = try JSONDecoder().decode(LongHorizonEffectDosePhraseEvidence.self,
      from: JSONSerialization.data(withJSONObject: object))
    var accumulator = LongHorizonEffectDoseAccumulator(rootSeed: 48_291)
    #expect(!stale.isComplete)
    #expect(accumulator.observe(stale) == .unavailable(.inconsistentEvidence))
    #expect(accumulator.report.phraseCount == 0)
    #expect(accumulator.report.barCount == 0)
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
    materialWorldFingerprint: phraseIndex.isMultiple(of: 2)
      ? "1111111111111111" : "2222222222222222",
    materialWorldGeneration: phraseIndex,
    graphRevision: phraseIndex,
    requestedEffectWorld: .neutral,
    realizedEffectWorld: .neutral,
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

@Suite("Fresh native late pulse-echo causality")
struct LatePulseTests {
  @Test("A late source can precede its wet return", arguments: [44_100.0, 48_000.0])
  @MainActor
  func lateSend(_ rate: Double) throws {
    let director = AutonomousSessionDirector(rootSeed: 173_205)
    var session = director.initialState()
    var fixture: (AutonomousPhrasePlan, Int, SynthPerformancePlan)?
    while session.memory.totalBars < 7_800 {
      let plan = director.plan(from: session)
      let synth = SynthPerformancePlan(scene: plan.scene, dna: plan.dna,
        kind: plan.kind, resolvedBars: plan.resolvedBars)
      if let index = synth.bars.indices.first(where: {
        guard $0 + 1 < synth.bars.count else { return false }
        let pulse = synth.bars[$0].pulseEchoTextureArticulation
        return plan.resolvedBars[$0].pulseEchoEnabled
          && (pulse.earliestPulseEchoOnsetStep ?? -1) >= 14
      }) { fixture = (plan, index, synth); break }
      session.advancePlanning(using: plan)
    }
    let (plan, index, synth) = try #require(fixture)
    let resolved = plan.resolvedBars[index]
    var state = RenderState()
    state.barIndex = resolved.performance.bar
    var workspace = RenderWorkspace()
    let first = VoiceRenderer.renderBar(scene: plan.scene, sampleRate: rate,
      state: &state, dna: plan.dna, resolved: resolved, synthWorld: synth.world,
      synthPerformance: synth.bars[index], workspace: &workspace, layer: .full,
      phraseKind: plan.kind)
    let source = first.pulseEchoReturnDriveRenderEvidence
    let nextResolved = plan.resolvedBars[index + 1]
    let noNewNotes = SynthPerformanceBar(bar: nextResolved.performance.bar,
      gesture: synth.bars[index].gesture, mutationAmount: synth.bars[index].mutationAmount,
      relationalSteps: synth.bars[index].relationalSteps, upperNotes: [])
    let second = VoiceRenderer.renderBar(scene: plan.scene, sampleRate: rate,
      state: &state, dna: plan.dna, resolved: nextResolved, synthWorld: synth.world,
      synthPerformance: noNewNotes, workspace: &workspace, layer: .full,
      phraseKind: plan.kind)
    let tail = second.pulseEchoReturnDriveRenderEvidence
    #expect(source.finite && tail.finite)
    #expect(source.currentSendRMS > 0)
    #expect(source.preDriveRMS == 0)
    #expect(source.postDriveRMS == 0)
    #expect(tail.currentSendRMS == 0)
    #expect(tail.preDriveRMS > 0)
    let bar = pulseDose(source)
    let tailBar = pulseDose(tail)
    print("LATE_PULSE_NATIVE " + String(decoding: try JSONSerialization.data(withJSONObject: [
      "rate": rate, "bar": resolved.performance.bar,
      "earliestOnset": source.earliestPulseEchoOnsetStep ?? -1,
      "delayFrames": source.delayFrameCount, "barFrames": source.renderedFrameCount,
      "sourceSendRMS": source.currentSendRMS, "sameBarWetRMS": source.preDriveRMS,
      "nextBarSendRMS": tail.currentSendRMS, "nextBarWetRMS": tail.preDriveRMS,
      "doseComplete": bar.isComplete, "tailDoseComplete": tailBar.isComplete,
      "sourceWetHash": source.preDriveSampleHash, "tailWetHash": tail.preDriveSampleHash
    ], options: [.sortedKeys]), as: UTF8.self))
    #expect(bar.pulseEchoEligible)
    #expect(!bar.pulseEchoActive && !bar.pulseEchoTailOnly)
    #expect(tailBar.pulseEchoActive && tailBar.pulseEchoTailOnly)
    #expect(tailBar.isComplete)
    #expect(bar.isComplete)
  }
}

private func pulseDose(_ pulse: PulseEchoReturnDriveRenderEvidence) -> LongHorizonEffectDoseBarEvidence {
  LongHorizonEffectDoseBarEvidence(bar: pulse.bar, expressiveGraphNodeCount: 0,
    graphInputFingerprint: "0123456789abcdef", graphOutputFingerprint: "0123456789abcdef",
    graphInputRMS: 1, graphOutputRMS: 1, instrumentEffectAccess: [],
    pulseEchoEligible: pulse.scoreEnabled && pulse.earliestPulseEchoOnsetStep != nil,
    pulseEchoSourceSendRMS: pulse.currentSendRMS, pulseEchoWetRMS: pulse.preDriveRMS,
    pulseEchoPreDriveFingerprint: pulse.preDriveSampleHash,
    pulseEchoPostDriveFingerprint: pulse.postDriveSampleHash,
    percussionEchoEligible: false, percussionEchoSourceRMS: 0, percussionEchoWetRMS: 0,
    percussionEchoSourceFingerprint: "23456789abcdef01", percussionEchoWetFingerprint: "23456789abcdef01",
    spatialFDNEligible: false, spatialFDNSourceRMS: 0, spatialFDNWetRMS: 0,
    spatialFDNActiveWetFrameCount: 0, spatialFDNRenderedFrameCount: pulse.renderedFrameCount,
    spatialFDNSourceFingerprint: "3456789abcdef012", spatialFDNWetLeftFingerprint: "3456789abcdef012",
    spatialFDNWetRightFingerprint: "3456789abcdef012", maximumMaskingOverlap: 0, bindingComplete: true)
}
