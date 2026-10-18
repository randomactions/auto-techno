import AutoTechnoCore
import Foundation
import Testing

@testable import AutoTechnoDSP

@Suite("Long-horizon score-owned energy coordination")
struct LongHorizonEnergyCoordinationTests {

  @inline(never)
  private func upperColorPreparedSummary(plan: AutonomousPhrasePlan,
      state: AutonomousSessionState, rate: Double) throws -> (hash: String, rolloff: Double, frames: Int) {
    var renderState = RenderState()
    renderState.barIndex = state.memory.totalBars
    let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
      plan: plan, sessionSeed: state.rootSeed, memory: state.memory, sampleRate: rate,
      incomingRenderState: renderState, incomingGraphState: GeneratedDSPContinuationState(),
      previousGraph: nil, incomingQualityState: state.quality,
      evaluator: AcceptingPrimaryTestEvaluator(), cancellationRequested: { false })
    if let failure = outcome.failure {
      Issue.record("Preparation failed at \(failure.stage.rawValue): \(failure.code.rawValue) \(failure.details)")
    }
    let prepared = try #require(outcome.preparedPhrase)
    #expect(prepared.plan == plan && prepared.playbackHardGatesPassed && prepared.commitEligible)
    let fullMix = prepared.selectedCandidateEvidence.fullMix
    #expect(fullMix.perceptual.finite)
    return (fullMix.sampleHash, fullMix.perceptual.spectralRolloff85MeanHz,
      prepared.audioPreflight.quality.analyzedFrameCount)
  }

  @Test("A measured rolloff failure reaches future score, canonical PCM and actual evidence")
  func upperColorPreparedRecoveryPipeline() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    let state = try energyState(operatorKind: .recover, rootSeed: 48_291,
      phraseIndex: 7, totalBars: 56, eligibleAtBar: 0, openDebt: false)
    let intent = ProfessionalQualityRecoveryIntentReducer.reduce([
      ProfessionalQualityRecoveryFailure(metric: .spectralRolloff85MeanHz,
        value: 5_600, lowerBound: 0, upperBound: 4_800)])
    let rejection = QualityDecision(policyVersion: "test-primary-calibrated.v1",
      outcome: .rejected, reasonCodes: [.guardrailRegressionV1], recoveryIntent: intent)
    #expect(rejection.isRetryableCandidateRejection)
    var retry = AutonomousQualityRetryContinuation()
    for _ in 0..<AutonomousQualityRetryContinuation.maximumOrdinal {
      retry = retry.recordingCalibratedRejection(decision: rejection, targetPhraseIndex: state.phraseIndex)
    }
    let context = retry.context(for: state.phraseIndex)
    #expect(context.ordinal == AutonomousQualityRetryContinuation.maximumOrdinal)
    #expect(context.intent.upperColor == .decrease && context.intent.spectralMovement == .hold)
    let neutral = director.plan(from: state, qualityRecoveryContext:
      AutonomousQualityRecoveryContext(wave: context.wave, ordinal: context.ordinal,
        presentedRepeatBars: context.presentedRepeatBars))
    let recovered = director.plan(from: state, qualityRecoveryContext: context)
    #expect(recovered.resolvedBars == neutral.resolvedBars)
    for rate in [44_100.0, 48_000.0] {
      // The no-inline summary returns no PCM/hold/continuation owner. Release
      // each independent prepared product before preparing its comparison.
      let before = try upperColorPreparedSummary(plan: neutral, state: state, rate: rate)
      let after = try upperColorPreparedSummary(plan: recovered, state: state, rate: rate)
      #expect(before.frames == after.frames && before.hash != after.hash)
      #expect(after.rolloff < before.rolloff)
      let row: [String: Any] = ["sampleRate": rate, "rootSeed": state.rootSeed,
        "ordinal": context.ordinal, "beforeRolloff85Hz": before.rolloff,
        "afterRolloff85Hz": after.rolloff, "beforePCM": before.hash, "afterPCM": after.hash,
        "frameCount": before.frames, "testPolicyOnly": true,
        "currentQualityQualification": false, "completeResourceQualification": false]
      let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
      print("AUTOTECHNO_UPPER_COLOR_PIPELINE " + String(decoding: data, as: UTF8.self))
    }
  }

  @Test("Every recovery coordinate binds quality continuation replay identity")
  func upperColorRecoveryIsReplayBound() {
    func fingerprint(_ intent: AutonomousQualityRecoveryIntent) -> String {
      let decision = QualityDecision(policyVersion: "test-primary-calibrated.v1",
        outcome: .rejected, reasonCodes: [.guardrailRegressionV1],
        candidateFingerprint: "same-candidate", evidenceFingerprint: "same-evidence",
        recoveryIntent: intent)
      return AutonomousTypedFingerprint.qualityState(QualityContinuationState(lastDecision: decision))
    }
    let neutral = fingerprint(.neutral)
    for intent in [AutonomousQualityRecoveryIntent(symbolicDensity: .decrease),
      AutonomousQualityRecoveryIntent(spectralMovement: .increase),
      AutonomousQualityRecoveryIntent(upperColor: .decrease),
      AutonomousQualityRecoveryIntent(kickCrestReduction: .increase)] {
      #expect(fingerprint(intent) != neutral)
      #expect(fingerprint(intent) == fingerprint(intent))
    }
    #expect(fingerprint(AutonomousQualityRecoveryIntent(upperColor: .decrease)) !=
      fingerprint(AutonomousQualityRecoveryIntent(upperColor: .increase)))
  }

  @Test("Absolute rolloff reduces to upper color independently of spectral movement")
  func upperColorRecoveryReductionAndSchema() throws {
    let decrease = ProfessionalQualityRecoveryIntentReducer.reduce([
      ProfessionalQualityRecoveryFailure(metric: .spectralRolloff85MeanHz,
        value: 5_600, lowerBound: 0, upperBound: 4_800)])
    #expect(decrease.upperColor == .decrease)
    #expect(decrease.spectralMovement == .hold)
    #expect(decrease.symbolicDensity == .hold && decrease.kickCrestReduction == .hold)
    let inRange = ProfessionalQualityRecoveryIntentReducer.reduce([
      ProfessionalQualityRecoveryFailure(metric: .spectralRolloff85MeanHz,
        value: 4_000, lowerBound: 0, upperBound: 4_800)])
    #expect(inRange.isNeutral)
    let invalid = ProfessionalQualityRecoveryIntentReducer.reduce([
      ProfessionalQualityRecoveryFailure(metric: .spectralRolloff85MeanHz,
        value: .nan, lowerBound: 0, upperBound: 4_800)])
    #expect(invalid.isNeutral)
    #expect(decrease.merging(AutonomousQualityRecoveryIntent(upperColor: .increase)).isNeutral)
    let data = try JSONEncoder().encode(decrease)
    #expect(try JSONDecoder().decode(AutonomousQualityRecoveryIntent.self, from: data) == decrease)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["schemaVersion"] = 1
    let oldSchema = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(AutonomousQualityRecoveryIntent.self, from: oldSchema)
    }
    object["schemaVersion"] = 2; object.removeValue(forKey: "upperColor")
    let missingCoordinate = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(AutonomousQualityRecoveryIntent.self, from: missingCoordinate)
    }
  }

  @Test("Upper color recovery changes only future resolved upper assignments")
  func upperColorRecoveryPreservesCanonicalGeometry() throws {
    var changedNotes = 0
    for root: UInt64 in [48_291, 246_813] {
      let director = AutonomousSessionDirector(rootSeed: root)
      let state = try energyState(operatorKind: .recover, rootSeed: root,
        phraseIndex: 7, totalBars: 56, eligibleAtBar: 0, openDebt: false)
      for ordinal in [0, 1, AutonomousQualityRetryContinuation.maximumOrdinal] {
        let neutralContext = AutonomousQualityRecoveryContext(ordinal: ordinal)
        let context = AutonomousQualityRecoveryContext(ordinal: ordinal,
          intent: AutonomousQualityRecoveryIntent(upperColor: .decrease))
        let original = director.plan(from: state, qualityRecoveryContext: neutralContext)
        let recovered = director.plan(from: state, qualityRecoveryContext: context)
        #expect(recovered == director.plan(from: state, qualityRecoveryContext: context))
        #expect(recovered.resolvedBars == original.resolvedBars)
        #expect(recovered.phraseComposition == original.phraseComposition)
        #expect(recovered.longHorizonEnergyCoordination == original.longHorizonEnergyCoordination)
        #expect(recovered.materialWorld == original.materialWorld)
        func synth(_ plan: AutonomousPhrasePlan) -> SynthPerformancePlan {
          SynthPerformancePlan(scene: plan.scene, dna: plan.dna, kind: plan.kind,
            resolvedBars: plan.resolvedBars, materialWorld: plan.materialWorld,
            compositionBars: plan.phraseComposition,
            qualityRecoveryContext: plan.qualityRecoveryContext)
        }
        let before = synth(original), after = synth(recovered)
        #expect(before.bars.count == after.bars.count)
        for (a, b) in zip(before.bars, after.bars) {
          #expect(a.foundationInstrument == b.foundationInstrument)
          #expect(a.upperNotes.count == b.upperNotes.count)
          for (old, new) in zip(a.upperNotes, b.upperNotes) {
            #expect(new.role == old.role && new.onsetStep == old.onsetStep)
            #expect(new.durationInSteps == old.durationInSteps && new.velocity == old.velocity)
            #expect(new.startFrequencyRatio == old.startFrequencyRatio && new.endFrequencyRatio == old.endFrequencyRatio)
            #expect(new.gate == old.gate && new.timbreIntent == old.timbreIntent)
            #expect(new.instrument.patch == old.instrument.patch && new.instrument.effects == old.instrument.effects)
            #expect(new.instrument.automation.shape == old.instrument.automation.shape)
            #expect(new.instrument.automation.motion == old.instrument.automation.motion)
            #expect(new.instrument.automation.space == old.instrument.automation.space)
            if ordinal == 0 { #expect(new.instrument == old.instrument) }
            else {
              #expect(new.instrument.automation.color <= old.instrument.automation.color)
              if new.instrument.automation.color < old.instrument.automation.color { changedNotes += 1 }
            }
          }
        }
        let foundation = InstrumentPalette.safeFoundation()
        #expect(foundation.applyingUpperColorRecovery(context) == foundation)
        #expect((0...1).contains(InstrumentPalette.safeUpper(role: .atmosphere)
          .applyingUpperColorRecovery(context).automation.color))
      }
    }
    #expect(changedNotes > 0)
  }

  private func upperColorSource(patch: InstrumentPatch, color: Double,
      rate: Double, frequency: Double = 220) throws -> (pcm: [Float], evidence: StreamingPerceptualEvidence, hash: String) {
    let frames = Int(rate * 3)
    let assignment = InstrumentAssignment(use: .atmosphere, patch: patch,
      automation: InstrumentAutomation(color: color, shape: 1, motion: 0.79, space: 0), effects: [])
    #expect(assignment.isValid && assignment.musicalPitchIdentity == .indefinitePitch)
    let note = AlienVoiceNote(startFrame: 0, durationFrames: frames, frequency: frequency,
      endFrequency: frequency, velocity: 0.8, gate: .retrigger, timbreIntent: .home,
      instrument: assignment, role: .atmosphere, articulation: .neutral,
      dryScale: 1, spatialReverbSend: 0, narrativeGainScale: 1, narrativeSpectralScale: 1)
    var output = [Float](repeating: 0, count: frames), measurement = output,
      architecture = output, indefinite = output, cluster = output, tail = output,
      echo = output, reverb = output
    var notes: [UpperNoteRenderEvidence] = [], state = SpectralTextureState()
    SpectralTextureVoice.render(&output, measurement: &measurement,
      architectureMeasurement: &architecture, indefinitePitchMeasurement: &indefinite,
      clusterMeasurement: &cluster, harmonicTailMeasurement: &tail,
      pulseEchoSend: &echo, spatialReverbSend: &reverb, noteRenderEvidence: &notes,
      notes: [note], sampleRate: rate, level: 0.04, state: &state)
    #expect(output == measurement && output.allSatisfy(\.isFinite))
    let evidence = try #require(StreamingPerceptualEvidenceAnalyzer.analyze(
      left: output, right: output, sampleRate: rate))
    #expect(evidence.finite && evidence.activeWindowCount > 0)
    var hash = StreamingFNV1a(); hash.domain("existing-dust-color-source-control.v1")
    for sample in output { hash.float(sample) }
    return (output, evidence, fixedWidthFingerprintHex(hash.value))
  }

  @Test("Authored noise color retains original sample fingerprints at both native rates")
  func upperColorAuthoredFingerprintsMatch() throws {
    for (rate, color, expected): (Double, Double, String) in [
      (44_100, 0.62, "da1d5d3ab2438330"), (44_100, 1, "c86fe6b7fe9b5f36"),
      (48_000, 0.62, "4c9ea4d18fd05990"), (48_000, 1, "d22299c1d6b1adcf")
    ] {
      #expect(try upperColorSource(patch: .dustCloud, color: color, rate: rate).hash == expected)
    }
  }

  @Test("Lower noise color changes real source spectra without adding pitch")
  func upperColorNoiseSourceResponse() throws {
    for rate in [44_100.0, 48_000.0] {
      for patch in [InstrumentPatch.alienNoise, .metalVeil, .dustCloud] {
        let home = try upperColorSource(patch: patch,
          color: InstrumentPalette.homeColor(for: patch), rate: rate)
        let lower = try upperColorSource(patch: patch, color: 0, rate: rate)
        let differentPitch = try upperColorSource(patch: patch, color: 0, rate: rate, frequency: 880)
        #expect(lower.pcm == differentPitch.pcm)
        #expect(lower.hash != home.hash)
        #expect(lower.evidence.spectralRolloff85MeanHz < home.evidence.spectralRolloff85MeanHz)
        #expect(lower.evidence.spectralCentroidMeanHz < home.evidence.spectralCentroidMeanHz)
        let row: [String: Any] = ["sampleRate": rate, "patch": patch.rawValue,
          "homeRolloff85Hz": home.evidence.spectralRolloff85MeanHz,
          "lowerRolloff85Hz": lower.evidence.spectralRolloff85MeanHz,
          "homePCM": home.hash, "lowerPCM": lower.hash,
          "indefinitePitchPreserved": lower.pcm == differentPitch.pcm,
          "calibrationEvidence": false, "completeQualityQualification": false]
        let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
        print("AUTOTECHNO_UPPER_COLOR_NATIVE " + String(decoding: data, as: UTF8.self))
      }
    }
  }

  @Test("Directed spectral recovery exchanges sparse boundary roles without adding density")
  func sparseSpectralRecoveryPreservesEpisodeAndDensity() throws {
    var exchanges = 0
    for seed: UInt64 in [48_291, 77_777, 90_909, 112_358, 141_421, 173_205, 246_813] {
      let director = AutonomousSessionDirector(rootSeed: seed)
      for phrase in 0..<32 {
        let state = try energyState(operatorKind: .reframe, rootSeed: seed,
          phraseIndex: phrase, totalBars: phrase * 8,
          eligibleAtBar: phrase * 8 + 64, openDebt: false)
        let neutral = director.plan(from: state,
          qualityRecoveryContext: AutonomousQualityRecoveryContext(wave: 0,
            ordinal: 1, presentedRepeatBars: 16, intent: .neutral))
        let context = AutonomousQualityRecoveryContext(wave: 0, ordinal: 1,
          presentedRepeatBars: 16,
          intent: AutonomousQualityRecoveryIntent(spectralMovement: .increase))
        let recovered = director.plan(from: state, qualityRecoveryContext: context)
        #expect(recovered == director.plan(from: state, qualityRecoveryContext: context))
        #expect(recovered.longHorizonEnergyCoordination == neutral.longHorizonEnergyCoordination)
        #expect(recovered.longHorizonSelection == neutral.longHorizonSelection)
        #expect(recovered.materialWorld == neutral.materialWorld)
        #expect(recovered.startBar == neutral.startBar)
        #expect(recovered.presentationStartBar == neutral.presentationStartBar)
        #expect(recovered.resolvedBars.count == neutral.resolvedBars.count)
        let focus = recovered.materialWorld.resolvedAxes.focusRole
        // Compare the first boundary before legacy gear-shift gestures can
        // independently change the supporting-role continuation.
        for (original, changed) in zip(neutral.resolvedBars.prefix(4),
                                       recovered.resolvedBars.prefix(4)) {
          let before = Set(original.performance.roles), after = Set(changed.performance.roles)
          #expect(before.count == after.count)
          #expect(after.contains(.foundation))
          if before.contains(focus) { #expect(after.contains(focus)) }
          if before != after {
            exchanges += 1
            #expect((changed.performance.bar + 1).isMultiple(of: 4))
            #expect(before.subtracting(after) == [.motif])
            #expect(after.subtracting(before) == [.percussion])
            #expect(changed.narrative.activeSupportingRoles.contains(.percussion))
            #expect(changed.ensemble.events.contains { $0.voice == .percussion })
            #expect(!changed.ensemble.events.contains { $0.voice == .motif })
          }
        }
      }
    }
    #expect(exchanges > 0)
  }

  @Test("Sparse exchanges leave initial, non-increase and structural roles unchanged")
  func sparseRecoveryProtectedRoles() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    var structuralCases = 0
    for kind in LongHorizonEpisodeOperator.allCases {
      for phrase in [0, 7, 16] {
        let state = try energyState(operatorKind: kind,
          phraseIndex: phrase, totalBars: phrase * 8, eligibleAtBar: 0,
          openDebt: kind == .payoff)
        for ordinal in [0, 1, AutonomousQualityRetryContinuation.maximumOrdinal] {
          let neutral = director.plan(from: state,
            qualityRecoveryContext: AutonomousQualityRecoveryContext(wave: 0,
              ordinal: ordinal, presentedRepeatBars: 16, intent: .neutral))
          for direction in [AutonomousQualityRecoveryDirection.increase, .decrease] {
            let candidate = director.plan(from: state,
              qualityRecoveryContext: AutonomousQualityRecoveryContext(wave: 0,
                ordinal: ordinal, presentedRepeatBars: 16,
                intent: AutonomousQualityRecoveryIntent(spectralMovement: direction)))
            let structural = candidate.kind == .majorBreak ||
              candidate.kind == .energyRelease || candidate.kind == .identityReturn
            if structural { structuralCases += 1 }
            if ordinal == 0 || direction == .decrease || structural {
              #expect(candidate.resolvedBars.map { $0.performance.roles } ==
                neutral.resolvedBars.map { $0.performance.roles })
            }
          }
        }
      }
    }
    #expect(structuralCases > 0)
  }

  @Test("Every episode target is carried by one exact phrase-boundary projection")
  func everyOperatorCarriesCanonicalTarget() throws {
    var rise: LongHorizonSemanticEnergyVector?
    var recover: LongHorizonSemanticEnergyVector?
    var payoff: LongHorizonSemanticEnergyVector?
    var recall: LongHorizonSemanticEnergyVector?
    for operatorKind in LongHorizonEpisodeOperator.allCases {
      let state = try energyState(
        operatorKind: operatorKind,
        eligibleAtBar: 0,
        openDebt: operatorKind == .payoff
      )
      let plan = AutonomousSessionDirector(rootSeed: 48_291).plan(from: state)
      let coordination = plan.longHorizonEnergyCoordination
      let realized = LongHorizonContinuationState.semanticEnergy(plan)

      #expect(coordination.schemaVersion == 1)
      #expect(
        coordination.schemaIdentifier
          == "autotechno-long-horizon-energy-coordination.v1")
      #expect(coordination.phraseIndex == plan.phraseIndex)
      #expect(coordination.startBar == plan.startBar)
      #expect(coordination.phraseKind == plan.kind)
      #expect(coordination.episodeID == state.memory.longHorizon.currentEpisode.id)
      #expect(coordination.operatorKind == operatorKind)
      #expect(coordination.reason == .episodeFulfillment)
      #expect(coordination.target == LongHorizonContinuationState.target(for: operatorKind))
      #expect(
        coordination.isConsistent(
          phraseIndex: plan.phraseIndex,
          startBar: plan.startBar,
          phraseKind: plan.kind,
          selection: plan.longHorizonSelection))
      switch operatorKind {
      case .rise: rise = realized
      case .recover: recover = realized
      case .payoff: payoff = realized
      case .recall: recall = realized
      case .maintain, .reframe: break
      }
    }
    guard let rise, let recover, let payoff, let recall else {
      Issue.record("Expected all directional energy witnesses")
      return
    }
    #expect(recover.foundationAuthority <= payoff.foundationAuthority)
    #expect(recover.roleDensity < payoff.roleDensity)
    #expect(recover.percussionActivity < rise.percussionActivity)
    #expect(recover.protagonistPresence < payoff.protagonistPresence)
    #expect(rise.harmonicDisclosure > 0)
    #expect(payoff.harmonicDisclosure > 0)
    #expect(recall.harmonicDisclosure > 0)
    #expect(recover.timbralMotionIntent < payoff.timbralMotionIntent)
    #expect(recover.spatialDistance > payoff.spatialDistance)
    #expect(rise.transitionExpectation > payoff.transitionExpectation)
  }

  @Test("Fallback and protected rare events use the exact all-hold projection")
  func neutralPathsAreExplicitAndReplayExactly() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    var invalid = AutonomousSessionState(
      rootSeed: 48_291,
      phraseIndex: 0,
      memory: TemporalMusicalMemory(totalBars: 4)
    )
    invalid.memory = TemporalMusicalMemory(
      totalBars: 4,
      longHorizon: LongHorizonContinuationState.initial(
        rootSeed: 48_291,
        startingPhraseIndex: 0,
        startingBar: 0
      )
    )
    let reserved = try energyState(
      operatorKind: .payoff,
      totalBars: 200,
      eligibleAtBar: 512,
      openDebt: true
    )
    let fallback = director.plan(from: invalid)
    let fallbackReplay = director.plan(from: invalid)
    let protected = director.plan(from: reserved)

    #expect(fallback == fallbackReplay)
    #expect(fallback.longHorizonSelection.reason == .conservativeFallback)
    #expect(fallback.longHorizonEnergyCoordination.reason == .conservativeFallback)
    #expect(fallback.longHorizonEnergyCoordination.target.isNeutral)
    #expect(protected.longHorizonSelection.reason == .reservedPayoff)
    #expect(protected.longHorizonEnergyCoordination.reason == .protectedRareEvent)
    #expect(protected.longHorizonEnergyCoordination.target.isNeutral)
    // Engine v52 binds recovery-intent v2, including its explicit hold color.
    // The prior v51 plan identity d65fb6874c05376d remains historical.
    #expect(AutonomousQualityRecoveryIntent.schemaVersion == 2)
    #expect(AutonomousTypedFingerprint.plan(fallback) == "f7e9ec81080f039e")
  }

  @Test("Coordination provenance round-trips and rejects unsupported schema")
  func provenanceIsStrictAndReplayable() throws {
    let state = try energyState(
      operatorKind: .rise,
      eligibleAtBar: 0,
      openDebt: false
    )
    let plan = AutonomousSessionDirector(rootSeed: 48_291).plan(from: state)
    let encoded = try JSONEncoder().encode(plan.longHorizonEnergyCoordination)
    let decoded = try JSONDecoder().decode(
      LongHorizonEnergyCoordination.self,
      from: encoded
    )
    let unsupported = try encodedEnergyCoordination(
      plan.longHorizonEnergyCoordination,
      replacing: "schemaIdentifier",
      with: "autotechno-long-horizon-energy-coordination.v999"
    )
    let inconsistentFallback = try encodedEnergyCoordination(
      .neutral(
        phraseIndex: 0,
        startBar: 0,
        phraseKind: .lock
      ),
      replacing: "selectionReason",
      with: LongHorizonPhraseSelectionReason.minimumHold.rawValue
    )

    #expect(decoded == plan.longHorizonEnergyCoordination)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        LongHorizonEnergyCoordination.self,
        from: unsupported
      )
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        LongHorizonEnergyCoordination.self,
        from: inconsistentFallback
      )
    }
  }

  @Test("Four-hour coordination stays bounded and preserves rare-event reserve")
  func fourHourProjectionIsBounded() {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    var state = director.initialState()
    var activeOperators = Set<String>()
    var protectedRareEventPhrases = 0
    var maximumPresenceSlew = 0.0
    var distantBarsPerMacro: [Int: Int] = [:]
    let percussionTiers: [PercussionGear] = [.anchor, .turnaround, .contrast, .lift]

    while state.memory.totalBars < 7_800 {
      let plan = director.plan(from: state)
      let coordination = plan.longHorizonEnergyCoordination
      #expect(
        coordination.isConsistent(
          phraseIndex: plan.phraseIndex,
          startBar: plan.startBar,
          phraseKind: plan.kind,
          selection: plan.longHorizonSelection))
      if coordination.reason == .episodeProgression || coordination.reason == .episodeFulfillment {
        if let operatorKind = coordination.operatorKind {
          activeOperators.insert(operatorKind.rawValue)
        }
      }
      if coordination.reason == .protectedRareEvent {
        protectedRareEventPhrases += 1
        #expect(coordination.target.isNeutral)
      }
      for resolved in plan.resolvedBars {
        let baselineGear: PercussionGear =
          switch (resolved.performance.bar % 16) / 4 {
          case 0: .anchor
          case 1: .lift
          case 2: .contrast
          default: .turnaround
          }
        let baselineTier = percussionTiers.firstIndex(of: baselineGear) ?? 0
        let resolvedTier = percussionTiers.firstIndex(of: resolved.percussionGear) ?? 0
        #expect((2...4).contains(resolved.performance.roles.count))
        #expect(abs(resolvedTier - baselineTier) <= 1)
        #expect(
          resolved.harmonicDisclosureRelationship
            == plan.materialWorld.resolvedAxes.harmonicRelationship)
        if coordination.target.protagonistPresence != .hold {
          maximumPresenceSlew = max(
            maximumPresenceSlew,
            abs(resolved.narrative.presenceEnd - resolved.narrative.presenceStart)
          )
        }
        if resolved.spatialContrast.depthPosition == .distant {
          distantBarsPerMacro[resolved.performance.bar / 16, default: 0] += 1
        }
      }
      state.advancePlanning(using: plan)
    }

    #expect(activeOperators == Set(LongHorizonEpisodeOperator.allCases.map(\.rawValue)))
    #expect(protectedRareEventPhrases == 249)
    #expect(maximumPresenceSlew <= 0.160_001)
    // Engine54 ordinary composition minimalization changes recorded capability
    // use counts. The prior engine52 score-state fixture was311f55d31923c807.
    // This is canonical score state, not a platform-native audio fingerprint;
    // independent macOS/Windows rendering qualification remains separate.
    #expect(state.memory.longHorizon.fingerprint == "4725bfe441405757")
    #expect(distantBarsPerMacro.values.allSatisfy { $0 <= 1 })
  }

  @Test("An active coordinated plan passes detached canonical preparation")
  func activeCoordinationPreparesCanonically() throws {
    let state = try energyState(
      operatorKind: .rise,
      eligibleAtBar: 0,
      openDebt: false
    )
    let plan = AutonomousSessionDirector(rootSeed: 48_291).plan(from: state)
    let candidate = AutonomousPhrasePreparer.prepareIfNotCancelled(
      plan: plan,
      sessionSeed: state.rootSeed,
      memory: state.memory,
      sampleRate: 8_000,
      incomingRenderState: RenderState(),
      incomingGraphState: GeneratedDSPContinuationState(),
      previousGraph: nil,
      incomingQualityState: state.quality,
      evaluator: AcceptingPrimaryTestEvaluator(),
      cancellationRequested: { false }
    )
    let prepared = try #require(candidate)

    #expect(prepared.plan == plan)
    #expect(!prepared.blocks.isEmpty)
    #expect(prepared.playbackHardGatesPassed)
    #expect(prepared.commitEligible)
  }
}

private func energyState(
  operatorKind: LongHorizonEpisodeOperator,
  rootSeed: UInt64 = 48_291,
  phraseIndex: Int = 0,
  totalBars: Int = 0,
  eligibleAtBar: Int,
  openDebt: Bool
) throws -> AutonomousSessionState {
  let initial = LongHorizonContinuationState.initial(
    rootSeed: rootSeed,
    startingPhraseIndex: phraseIndex,
    startingBar: totalBars
  )
  let encoded = try JSONEncoder().encode(initial)
  guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
    var episode = object["currentEpisode"] as? [String: Any]
  else {
    throw DecodingError.dataCorrupted(
      .init(codingPath: [], debugDescription: "Expected continuation JSON object"))
  }
  let midpoint = LongHorizonSemanticEnergyVector(
    foundationAuthority: 0.5,
    roleDensity: 0.5,
    percussionActivity: 0.5,
    protagonistPresence: 0.5,
    harmonicDisclosure: 0.5,
    timbralMotionIntent: 0.5,
    spatialDistance: 0.5,
    transitionExpectation: 0.5
  )
  episode["operatorKind"] = operatorKind.rawValue
  episode["target"] = try JSONSerialization.jsonObject(
    with: JSONEncoder().encode(
      LongHorizonContinuationState.target(for: operatorKind)))
  episode["startEnergy"] = try JSONSerialization.jsonObject(
    with: JSONEncoder().encode(midpoint))
  episode["startedAtBar"] = max(0, totalBars - 128)
  episode["minimumHoldUntilBar"] = eligibleAtBar
  episode["dueByBar"] = max(eligibleAtBar + 128, totalBars + 128)
  object["currentEpisode"] = episode
  object["lastSemanticEnergy"] = try JSONSerialization.jsonObject(
    with: JSONEncoder().encode(midpoint))
  let continuation = try JSONDecoder().decode(
    LongHorizonContinuationState.self,
    from: JSONSerialization.data(withJSONObject: object)
  )
  let debts =
    openDebt
    ? [
      SessionDramaticDebt(
        id: 77,
        openedAtBar: max(0, totalBars - 64),
        dueByBar: totalBars + 128,
        source: .contrast
      )
    ] : []
  return AutonomousSessionState(
    rootSeed: rootSeed,
    phraseIndex: phraseIndex,
    memory: TemporalMusicalMemory(
      totalBars: totalBars,
      openDebts: debts,
      longHorizon: continuation
    )
  )
}

private func encodedEnergyCoordination(
  _ coordination: LongHorizonEnergyCoordination,
  replacing key: String,
  with value: Any
) throws -> Data {
  let encoded = try JSONEncoder().encode(coordination)
  guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
    throw DecodingError.dataCorrupted(
      .init(codingPath: [], debugDescription: "Expected coordination JSON object"))
  }
  object[key] = value
  return try JSONSerialization.data(withJSONObject: object)
}
