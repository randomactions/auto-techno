import AutoTechnoCore
import Foundation

package enum LongHorizonEffectDoseSchema {
  package static let schemaVersion = 1
  package static let schemaIdentifier =
    "autotechno-long-horizon-effect-dose.v1"
  package static let sentenceHistoryCapacity = 16
  package static let qualificationReason =
    "no-calibrated-long-horizon-policy"
}

package enum LongHorizonEffectFamily: String, CaseIterable, Codable, Hashable,
  Sendable
{
  case generatedGraph = "generated-graph"
  case pulseEcho = "pulse-echo"
  case percussionEchoTexture = "percussion-echo-texture"
  case spatialFDN = "spatial-fdn"
}

package enum LongHorizonEffectDoseAvailability: String, Codable, Sendable {
  case available
  case unavailable
}

package enum LongHorizonEffectDoseUnavailableReason: String, Codable, Sendable {
  case noObservations = "no-observations"
  case rootSeedMismatch = "root-seed-mismatch"
  case phraseIndexDiscontinuity = "phrase-index-discontinuity"
  case barDiscontinuity = "bar-discontinuity"
  case inconsistentEvidence = "inconsistent-evidence"
  case counterOverflow = "counter-overflow"
}

package enum LongHorizonEffectDoseObservationResult: Equatable, Sendable {
  case accepted
  case unavailable(LongHorizonEffectDoseUnavailableReason)
}

package struct LongHorizonEffectDoseBarEvidence: Codable, Equatable, Sendable {
  package let bar: Int
  package let expressiveGraphNodeCount: Int
  package let graphInputFingerprint: String
  package let graphOutputFingerprint: String
  package let graphInputRMS: Double
  package let graphOutputRMS: Double
  package let graphOutputToInputDB: Double?
  package let graphSignalChanged: Bool
  package let instrumentEffectAccess: [String]
  package let pulseEchoEligible: Bool
  package let pulseEchoActive: Bool
  package let pulseEchoTailOnly: Bool
  package let pulseEchoSourceSendRMS: Double
  package let pulseEchoWetRMS: Double
  package let pulseEchoPreDriveFingerprint: String
  package let pulseEchoPostDriveFingerprint: String
  package let percussionEchoEligible: Bool
  package let percussionEchoActive: Bool
  package let percussionEchoSourceRMS: Double
  package let percussionEchoWetRMS: Double
  package let percussionEchoSourceFingerprint: String
  package let percussionEchoWetFingerprint: String
  package let spatialFDNEligible: Bool
  package let spatialFDNActive: Bool
  package let spatialFDNTailOnly: Bool
  package let spatialFDNSourceRMS: Double
  package let spatialFDNWetRMS: Double
  package let spatialFDNWetFrameOccupancy: Double
  package let spatialFDNSourceFingerprint: String
  package let spatialFDNWetLeftFingerprint: String
  package let spatialFDNWetRightFingerprint: String
  package let combinedWetRMS: Double
  package let combinedWetToDryDB: Double?
  package let maximumMaskingOverlap: Double
  package let bindingComplete: Bool

  package init(
    bar: Int,
    expressiveGraphNodeCount: Int,
    graphInputFingerprint: String,
    graphOutputFingerprint: String,
    graphInputRMS: Double,
    graphOutputRMS: Double,
    instrumentEffectAccess: [String],
    pulseEchoEligible: Bool,
    pulseEchoSourceSendRMS: Double,
    pulseEchoWetRMS: Double,
    pulseEchoPreDriveFingerprint: String,
    pulseEchoPostDriveFingerprint: String,
    percussionEchoEligible: Bool,
    percussionEchoSourceRMS: Double,
    percussionEchoWetRMS: Double,
    percussionEchoSourceFingerprint: String,
    percussionEchoWetFingerprint: String,
    spatialFDNEligible: Bool,
    spatialFDNSourceRMS: Double,
    spatialFDNWetRMS: Double,
    spatialFDNActiveWetFrameCount: Int,
    spatialFDNRenderedFrameCount: Int,
    spatialFDNSourceFingerprint: String,
    spatialFDNWetLeftFingerprint: String,
    spatialFDNWetRightFingerprint: String,
    maximumMaskingOverlap: Double,
    bindingComplete: Bool
  ) {
    self.bar = bar
    self.expressiveGraphNodeCount = max(0, expressiveGraphNodeCount)
    self.graphInputFingerprint = graphInputFingerprint
    self.graphOutputFingerprint = graphOutputFingerprint
    self.graphInputRMS = graphInputRMS
    self.graphOutputRMS = graphOutputRMS
    graphOutputToInputDB = Self.levelRelationshipDB(
      numerator: graphOutputRMS,
      denominator: graphInputRMS
    )
    graphSignalChanged = graphInputFingerprint != graphOutputFingerprint
    let requestedEffects = Set(instrumentEffectAccess)
    self.instrumentEffectAccess = InstrumentEffect.allCases
      .map(\.rawValue)
      .filter(requestedEffects.contains)
    self.pulseEchoEligible = pulseEchoEligible
    pulseEchoActive = pulseEchoWetRMS > 0
    pulseEchoTailOnly = pulseEchoWetRMS > 0 && pulseEchoSourceSendRMS == 0
    self.pulseEchoSourceSendRMS = pulseEchoSourceSendRMS
    self.pulseEchoWetRMS = pulseEchoWetRMS
    self.pulseEchoPreDriveFingerprint = pulseEchoPreDriveFingerprint
    self.pulseEchoPostDriveFingerprint = pulseEchoPostDriveFingerprint
    self.percussionEchoEligible = percussionEchoEligible
    percussionEchoActive = percussionEchoWetRMS > 0
    self.percussionEchoSourceRMS = percussionEchoSourceRMS
    self.percussionEchoWetRMS = percussionEchoWetRMS
    self.percussionEchoSourceFingerprint = percussionEchoSourceFingerprint
    self.percussionEchoWetFingerprint = percussionEchoWetFingerprint
    self.spatialFDNEligible = spatialFDNEligible
    spatialFDNActive = spatialFDNWetRMS > 0
    spatialFDNTailOnly = spatialFDNWetRMS > 0 && spatialFDNSourceRMS == 0
    self.spatialFDNSourceRMS = spatialFDNSourceRMS
    self.spatialFDNWetRMS = spatialFDNWetRMS
    spatialFDNWetFrameOccupancy =
      spatialFDNRenderedFrameCount > 0
      ? Double(spatialFDNActiveWetFrameCount) / Double(spatialFDNRenderedFrameCount) : 0
    self.spatialFDNSourceFingerprint = spatialFDNSourceFingerprint
    self.spatialFDNWetLeftFingerprint = spatialFDNWetLeftFingerprint
    self.spatialFDNWetRightFingerprint = spatialFDNWetRightFingerprint
    combinedWetRMS = sqrt(
      pulseEchoWetRMS * pulseEchoWetRMS + percussionEchoWetRMS * percussionEchoWetRMS
        + spatialFDNWetRMS * spatialFDNWetRMS
    )
    combinedWetToDryDB = Self.levelRelationshipDB(
      numerator: combinedWetRMS,
      denominator: graphInputRMS
    )
    self.maximumMaskingOverlap = maximumMaskingOverlap
    self.bindingComplete =
      bindingComplete && spatialFDNRenderedFrameCount > 0
      && (0...spatialFDNRenderedFrameCount).contains(spatialFDNActiveWetFrameCount)
  }

  package var isComplete: Bool {
    let expectedEffects = InstrumentEffect.allCases.map(\.rawValue).filter {
      instrumentEffectAccess.contains($0)
    }
    let graphRelationship = Self.levelRelationshipDB(
      numerator: graphOutputRMS,
      denominator: graphInputRMS
    )
    let wetRelationship = Self.levelRelationshipDB(
      numerator: combinedWetRMS,
      denominator: graphInputRMS
    )
    let pulseIsCausal = !pulseEchoActive || pulseEchoEligible || pulseEchoTailOnly
    let percussionIsCausal = percussionEchoActive == percussionEchoEligible
    let spatialIsCausal = !spatialFDNActive || spatialFDNEligible || spatialFDNTailOnly
    let silentPulseIsExact =
      pulseEchoActive || (pulseEchoSourceSendRMS == 0 && pulseEchoWetRMS == 0)
    let silentPercussionIsExact =
      percussionEchoActive || (percussionEchoSourceRMS == 0 && percussionEchoWetRMS == 0)
    let silentSpatialIsExact = spatialFDNActive || spatialFDNWetRMS == 0
    return bindingComplete && bar >= 0 && expressiveGraphNodeCount >= 0
      && Self.isFingerprint(graphInputFingerprint) && Self.isFingerprint(graphOutputFingerprint)
      && graphSignalChanged == (graphInputFingerprint != graphOutputFingerprint)
      && graphOutputToInputDB == graphRelationship && instrumentEffectAccess == expectedEffects
      && instrumentEffectAccess.count == Set(instrumentEffectAccess).count
      && [
        graphInputRMS, graphOutputRMS, pulseEchoSourceSendRMS,
        pulseEchoWetRMS, percussionEchoSourceRMS,
        percussionEchoWetRMS, spatialFDNSourceRMS,
        spatialFDNWetRMS, spatialFDNWetFrameOccupancy,
        combinedWetRMS, maximumMaskingOverlap,
      ].allSatisfy { $0.isFinite && $0 >= 0 } && (0...1).contains(spatialFDNWetFrameOccupancy)
      && (0...1).contains(maximumMaskingOverlap) && pulseEchoActive == (pulseEchoWetRMS > 0)
      && pulseEchoTailOnly == (pulseEchoWetRMS > 0 && pulseEchoSourceSendRMS == 0)
      && percussionEchoActive == (percussionEchoWetRMS > 0)
      && spatialFDNActive == (spatialFDNWetRMS > 0)
      && spatialFDNTailOnly == (spatialFDNWetRMS > 0 && spatialFDNSourceRMS == 0) && pulseIsCausal
      && percussionIsCausal && spatialIsCausal && silentPulseIsExact && silentPercussionIsExact
      && silentSpatialIsExact && Self.isFingerprint(pulseEchoPreDriveFingerprint)
      && Self.isFingerprint(pulseEchoPostDriveFingerprint)
      && Self.isFingerprint(percussionEchoSourceFingerprint)
      && Self.isFingerprint(percussionEchoWetFingerprint)
      && Self.isFingerprint(spatialFDNSourceFingerprint)
      && Self.isFingerprint(spatialFDNWetLeftFingerprint)
      && Self.isFingerprint(spatialFDNWetRightFingerprint)
      && combinedWetRMS
        == sqrt(
          pulseEchoWetRMS * pulseEchoWetRMS + percussionEchoWetRMS * percussionEchoWetRMS
            + spatialFDNWetRMS * spatialFDNWetRMS
        )
      && combinedWetToDryDB == wetRelationship
  }

  private static func levelRelationshipDB(
    numerator: Double,
    denominator: Double
  ) -> Double? {
    guard numerator.isFinite, denominator.isFinite,
      numerator > 0, denominator > 0
    else { return nil }
    return 20 * (log10(numerator) - log10(denominator))
  }

  private static func isFingerprint(_ value: String) -> Bool {
    value.count == 16
      && value.utf8.allSatisfy { byte in
        (48...57).contains(byte) || (97...102).contains(byte)
      }
  }
}

package struct LongHorizonEffectFamilyDose: Codable, Equatable, Sendable {
  package let family: LongHorizonEffectFamily
  package let eligibleBarCount: Int
  package let activeBarCount: Int
  package let tailOnlyBarCount: Int
  package let recoveryCount: Int
  package let maximumActiveRunBars: Int
  package let wetBarOccupancy: Double
  package let meanReturnToSourceDB: Double?
  package let maximumReturnToSourceDB: Double?
}

package struct LongHorizonEffectSentenceEvidence: Codable, Equatable, Sendable {
  package let sentence: LongHorizonEffectSentence
  package let realized: Bool
  package let bindingComplete: Bool
  package let sourceSampleFingerprint: String
  package let returnSampleFingerprint: String
  package let sourceRMS: Double
  package let returnRMS: Double
  package let maximumMaskingOverlap: Double
  package let tailClearedByPhraseEnd: Bool

  package var isComplete: Bool {
    bindingComplete && realized && sourceRMS > 0 && returnRMS > 0 && sourceRMS.isFinite
      && returnRMS.isFinite && (0...1).contains(maximumMaskingOverlap)
      && Self.isFingerprint(sourceSampleFingerprint) && Self.isFingerprint(returnSampleFingerprint)
      && sourceSampleFingerprint != returnSampleFingerprint && tailClearedByPhraseEnd
  }

  private static func isFingerprint(_ value: String) -> Bool {
    value.count == 16
      && value.utf8.allSatisfy { byte in
        (48...57).contains(byte) || (97...102).contains(byte)
      }
  }
}

/// Phrase-owned reduction of exact detached render evidence. No sample buffer,
/// mutable renderer state, or callback-owned object crosses this boundary.
package struct LongHorizonEffectDosePhraseEvidence: Codable, Equatable, Sendable {
  package let schemaVersion: Int
  package let schemaIdentifier: String
  package let rootSeed: UInt64
  package let phraseIndex: Int
  package let startBar: Int
  package let barCount: Int
  package let phraseKind: AutonomousPhraseKind
  package let planFingerprint: String
  package let plannedSentence: LongHorizonEffectSentence?
  package let realizedSentence: LongHorizonEffectSentenceEvidence?
  package let bars: [LongHorizonEffectDoseBarEvidence]
  package let families: [LongHorizonEffectFamilyDose]

  package init(
    rootSeed: UInt64,
    phraseIndex: Int,
    startBar: Int,
    phraseKind: AutonomousPhraseKind,
    planFingerprint: String,
    plannedSentence: LongHorizonEffectSentence?,
    realizedSentence: LongHorizonEffectSentenceEvidence?,
    bars: [LongHorizonEffectDoseBarEvidence]
  ) {
    schemaVersion = LongHorizonEffectDoseSchema.schemaVersion
    schemaIdentifier = LongHorizonEffectDoseSchema.schemaIdentifier
    self.rootSeed = rootSeed
    self.phraseIndex = phraseIndex
    self.startBar = startBar
    barCount = bars.count
    self.phraseKind = phraseKind
    self.planFingerprint = planFingerprint
    self.plannedSentence = plannedSentence
    self.realizedSentence = realizedSentence
    self.bars = bars
    families = Self.familyDoses(from: bars)
  }

  package static func make(
    prepared: PreparedAutonomousPhrase
  ) -> LongHorizonEffectDosePhraseEvidence? {
    let plan = prepared.plan
    let vector = prepared.selectedCandidateEvidence
    let blocks = prepared.blocks
    let count = blocks.count
    guard vector.isComplete,
      count == plan.barCount,
      vector.planFingerprint == AutonomousTypedFingerprint.plan(plan),
      vector.instruments.count == count,
      vector.percussionEchoTexture.count == count,
      vector.pulseEchoDrive.count == count,
      vector.spatialFDN.count == count,
      vector.masking.count == count
    else {
      return nil
    }

    let expressiveNodeCount = prepared.graph.nodes.filter { $0.mix > 0 }.count
    var bars: [LongHorizonEffectDoseBarEvidence] = []
    bars.reserveCapacity(count)
    for index in blocks.indices {
      let block = blocks[index]
      let instrument = vector.instruments[index]
      let percussion = vector.percussionEchoTexture[index]
      let pulse = vector.pulseEchoDrive[index]
      let spatial = vector.spatialFDN[index]
      let masking = vector.masking[index]
      let expectedBar = plan.startBar.addingReportingOverflow(index)
      guard !expectedBar.overflow,
        block.bar == expectedBar.partialValue,
        instrument.bar == block.bar,
        percussion.bar == block.bar,
        pulse.bar == block.bar,
        spatial.bar == block.bar,
        masking.bar == block.bar
      else {
        return nil
      }
      let effectAccess = instrument.architectures.flatMap { architecture in
        architecture.assignments.flatMap(\.effects)
      }
      let percussionEligible =
        percussion.normalRelation(
          phraseKind: plan.kind
        ) != nil
      let maximumOverlap =
        masking.observations
        .map(\.maximumOverlap).max() ?? 0
      let evidence = LongHorizonEffectDoseBarEvidence(
        bar: block.bar,
        expressiveGraphNodeCount: expressiveNodeCount,
        graphInputFingerprint:
          block.graphInputRemainderTimbreEvidence.fingerprint,
        graphOutputFingerprint:
          block.postGraphRemainderTimbreEvidence.fingerprint,
        graphInputRMS: block.graphInputRemainderTimbreEvidence.rms,
        graphOutputRMS: block.postGraphRemainderTimbreEvidence.rms,
        instrumentEffectAccess: effectAccess,
        pulseEchoEligible:
          pulse.scoreEnabled && pulse.earliestPulseEchoOnsetStep != nil,
        pulseEchoSourceSendRMS: pulse.currentSendRMS,
        pulseEchoWetRMS: pulse.preDriveRMS,
        pulseEchoPreDriveFingerprint: pulse.preDriveSampleHash,
        pulseEchoPostDriveFingerprint: pulse.postDriveSampleHash,
        percussionEchoEligible: percussionEligible,
        percussionEchoSourceRMS: percussion.inputRMS,
        percussionEchoWetRMS: percussion.returnRMS,
        percussionEchoSourceFingerprint: percussion.inputSampleHash,
        percussionEchoWetFingerprint: percussion.returnSampleHash,
        spatialFDNEligible:
          spatial.inputRMS > 0 || spatial.carrierVoice != nil,
        spatialFDNSourceRMS: spatial.inputRMS,
        spatialFDNWetRMS: spatial.wetRMS,
        spatialFDNActiveWetFrameCount: spatial.activeWetFrameCount,
        spatialFDNRenderedFrameCount: spatial.renderedFrameCount,
        spatialFDNSourceFingerprint: spatial.inputSampleHash,
        spatialFDNWetLeftFingerprint: spatial.wetLeftSampleHash,
        spatialFDNWetRightFingerprint: spatial.wetRightSampleHash,
        maximumMaskingOverlap: maximumOverlap,
        bindingComplete:
          percussion.bindingValid && percussion.renderPassesMatch && pulse.bindingValid
          && spatial.bindingValid
      )
      guard evidence.isComplete else { return nil }
      bars.append(evidence)
    }

    let realized = plan.longHorizonEffectSentence.flatMap { sentence in
      Self.realizedSentence(
        sentence,
        phraseKind: plan.kind,
        vector: vector
      )
    }
    let evidence = LongHorizonEffectDosePhraseEvidence(
      rootSeed: prepared.graph.sessionSeed,
      phraseIndex: plan.phraseIndex,
      startBar: plan.startBar,
      phraseKind: plan.kind,
      planFingerprint: vector.planFingerprint,
      plannedSentence: plan.longHorizonEffectSentence,
      realizedSentence: realized,
      bars: bars
    )
    return evidence.isComplete ? evidence : nil
  }

  package var isComplete: Bool {
    let endBar = startBar.addingReportingOverflow(barCount)
    let exactBars = bars.indices.allSatisfy {
      let expected = startBar.addingReportingOverflow($0)
      return !expected.overflow && bars[$0].bar == expected.partialValue
        && bars[$0].isComplete
    }
    let plannedSentenceConsistent =
      plannedSentence.map {
        $0.phraseIndex == phraseIndex && $0.phraseKind == phraseKind
          && !endBar.overflow && (startBar..<endBar.partialValue).contains($0.sourceBar)
      } ?? true
    let sentenceComplete: Bool
    switch (plannedSentence, realizedSentence) {
    case (nil, nil):
      sentenceComplete = true
    case (let planned?, let realized?):
      let sourceBar = bars.first { $0.bar == planned.sourceBar }
      sentenceComplete =
        realized.sentence == planned && realized.isComplete
        && sourceBar?.percussionEchoEligible == true
        && sourceBar?.percussionEchoActive == true
        && sourceBar?.percussionEchoSourceFingerprint
          == realized.sourceSampleFingerprint
        && sourceBar?.percussionEchoWetFingerprint
          == realized.returnSampleFingerprint
        && sourceBar?.percussionEchoSourceRMS == realized.sourceRMS
        && sourceBar?.percussionEchoWetRMS == realized.returnRMS
        && sourceBar?.maximumMaskingOverlap == realized.maximumMaskingOverlap
    default:
      sentenceComplete = false
    }
    return schemaVersion == LongHorizonEffectDoseSchema.schemaVersion
      && schemaIdentifier == LongHorizonEffectDoseSchema.schemaIdentifier && phraseIndex >= 0
      && startBar >= 0 && !endBar.overflow && barCount > 0 && barCount == bars.count
      && barCount <= AutonomousCandidateEvaluationVector.maximumBarCount
      && plannedSentenceConsistent && Self.isFingerprint(planFingerprint) && exactBars
      && sentenceComplete && families == Self.familyDoses(from: bars)
  }

  private static func realizedSentence(
    _ sentence: LongHorizonEffectSentence,
    phraseKind: AutonomousPhraseKind,
    vector: AutonomousCandidateEvaluationVector
  ) -> LongHorizonEffectSentenceEvidence? {
    guard
      let barIndex = vector.percussionEchoTexture.firstIndex(where: {
        $0.bar == sentence.sourceBar
      }), vector.masking.indices.contains(barIndex)
    else {
      return nil
    }
    let record = vector.percussionEchoTexture[barIndex]
    let expectedRelation: PercussionEchoTextureRelation =
      sentence.capability == .gatedPercussionEcho
      ? .gatedEcho : .anticipationSwell
    guard record.normalRelation(phraseKind: phraseKind) == expectedRelation,
      record.active, record.bindingValid, record.renderPassesMatch,
      record.inputStep == sentence.sourceStep,
      record.outputStartStep == sentence.answerStartStep,
      record.outputEndStep == sentence.answerEndStep
    else {
      return nil
    }
    let evidence = LongHorizonEffectSentenceEvidence(
      sentence: sentence,
      realized: true,
      bindingComplete: true,
      sourceSampleFingerprint: record.inputSampleHash,
      returnSampleFingerprint: record.returnSampleHash,
      sourceRMS: record.inputRMS,
      returnRMS: record.returnRMS,
      maximumMaskingOverlap: vector.masking[barIndex].observations
        .map(\.maximumOverlap).max() ?? 0,
      tailClearedByPhraseEnd:
        record.outOfWindowNonzeroSampleCount == 0
        && record.lastOutputSampleBitPattern & 0x7fff_ffff == 0
    )
    return evidence.isComplete ? evidence : nil
  }

  private static func familyDoses(
    from bars: [LongHorizonEffectDoseBarEvidence]
  ) -> [LongHorizonEffectFamilyDose] {
    LongHorizonEffectFamily.allCases.map { family in
      var eligible = 0
      var active = 0
      var tailOnly = 0
      var recoveries = 0
      var activeRun = 0
      var maximumActiveRun = 0
      var previousActive = false
      var relationships: [Double] = []
      for bar in bars {
        let state = bar.state(for: family)
        if state.eligible { eligible += 1 }
        if state.active {
          active += 1
          activeRun += 1
          maximumActiveRun = max(maximumActiveRun, activeRun)
        } else {
          if previousActive { recoveries += 1 }
          activeRun = 0
        }
        if state.tailOnly { tailOnly += 1 }
        if let relationship = state.returnToSourceDB {
          relationships.append(relationship)
        }
        previousActive = state.active
      }
      return LongHorizonEffectFamilyDose(
        family: family,
        eligibleBarCount: eligible,
        activeBarCount: active,
        tailOnlyBarCount: tailOnly,
        recoveryCount: recoveries,
        maximumActiveRunBars: maximumActiveRun,
        wetBarOccupancy: bars.isEmpty
          ? 0 : Double(active) / Double(bars.count),
        meanReturnToSourceDB: relationships.isEmpty
          ? nil : relationships.reduce(0, +) / Double(relationships.count),
        maximumReturnToSourceDB: relationships.max()
      )
    }
  }

  private static func isFingerprint(_ value: String) -> Bool {
    value.count == 16
      && value.utf8.allSatisfy { byte in
        (48...57).contains(byte) || (97...102).contains(byte)
      }
  }
}

extension LongHorizonEffectDoseBarEvidence {
  fileprivate struct FamilyState {
    let eligible: Bool
    let active: Bool
    let tailOnly: Bool
    let returnToSourceDB: Double?
  }

  fileprivate func state(for family: LongHorizonEffectFamily) -> FamilyState {
    switch family {
    case .generatedGraph:
      FamilyState(
        eligible: expressiveGraphNodeCount > 0,
        active: expressiveGraphNodeCount > 0 && graphSignalChanged,
        tailOnly: false,
        returnToSourceDB: graphOutputToInputDB
      )
    case .pulseEcho:
      FamilyState(
        eligible: pulseEchoEligible,
        active: pulseEchoActive,
        tailOnly: pulseEchoTailOnly,
        returnToSourceDB: Self.levelRelationshipDB(
          numerator: pulseEchoWetRMS,
          denominator: pulseEchoSourceSendRMS
        )
      )
    case .percussionEchoTexture:
      FamilyState(
        eligible: percussionEchoEligible,
        active: percussionEchoActive,
        tailOnly: false,
        returnToSourceDB: Self.levelRelationshipDB(
          numerator: percussionEchoWetRMS,
          denominator: percussionEchoSourceRMS
        )
      )
    case .spatialFDN:
      FamilyState(
        eligible: spatialFDNEligible,
        active: spatialFDNActive,
        tailOnly: spatialFDNTailOnly,
        returnToSourceDB: Self.levelRelationshipDB(
          numerator: spatialFDNWetRMS,
          denominator: spatialFDNSourceRMS
        )
      )
    }
  }
}

package struct LongHorizonEffectFamilyReport: Codable, Equatable, Sendable {
  package let family: LongHorizonEffectFamily
  package let eligibleBarCount: Int
  package let activeBarCount: Int
  package let activationCount: Int
  package let tailOnlyBarCount: Int
  package let recoveryCount: Int
  package let maximumActiveRunBars: Int
  package let lastActiveBar: Int?
  package let wetBarOccupancy: Double
  package let minimumInactiveGapBars: Int?
  package let maximumInactiveGapBars: Int?
  package let meanInactiveGapBars: Double?
  package let meanReturnToSourceDB: Double?
  package let maximumReturnToSourceDB: Double?
}

package struct LongHorizonEffectDoseReport: Codable, Equatable, Sendable {
  package let schemaVersion: Int
  package let schemaIdentifier: String
  package let availability: LongHorizonEffectDoseAvailability
  package let unavailableReason: LongHorizonEffectDoseUnavailableReason?
  package let qualificationStatus: String
  package let qualificationReason: String
  package let rootSeed: UInt64
  package let phraseCount: Int
  package let barCount: Int
  package let families: [LongHorizonEffectFamilyReport]
  package let recentSentences: [LongHorizonEffectSentenceEvidence]
}

/// Fixed-capacity session accumulator for dose, recovery, and recurrence.
/// Observation is transactional: invalid input never changes accepted counts.
package struct LongHorizonEffectDoseAccumulator: Sendable {
  private struct FamilyState: Sendable {
    var eligible = 0
    var active = 0
    var activations = 0
    var tailOnly = 0
    var recoveries = 0
    var currentActiveRun = 0
    var maximumActiveRun = 0
    var lastActiveBar: Int?
    var seenActive = false
    var previousActive = false
    var currentInactiveGap = 0
    var minimumInactiveGap: Int?
    var maximumInactiveGap: Int?
    var inactiveGapSum = 0
    var inactiveGapCount = 0
    var relationshipSum = 0.0
    var relationshipCount = 0
    var maximumRelationship: Double?
  }

  private let rootSeed: UInt64
  private var expectedPhraseIndex: Int
  private var expectedBar: Int
  private var phraseCount = 0
  private var barCount = 0
  private var states = LongHorizonEffectFamily.allCases.map { _ in
    FamilyState()
  }
  private var recentSentences: [LongHorizonEffectSentenceEvidence] = []
  private var unavailableReason: LongHorizonEffectDoseUnavailableReason?

  package init(
    rootSeed: UInt64,
    startingPhraseIndex: Int = 0,
    startingBar: Int = 0
  ) {
    self.rootSeed = rootSeed
    expectedPhraseIndex = max(0, startingPhraseIndex)
    expectedBar = max(0, startingBar)
  }

  package mutating func observe(
    _ evidence: LongHorizonEffectDosePhraseEvidence
  ) -> LongHorizonEffectDoseObservationResult {
    if let unavailableReason {
      return .unavailable(unavailableReason)
    }
    let reason: LongHorizonEffectDoseUnavailableReason?
    if !evidence.isComplete {
      reason = .inconsistentEvidence
    } else if evidence.rootSeed != rootSeed {
      reason = .rootSeedMismatch
    } else if evidence.phraseIndex != expectedPhraseIndex {
      reason = .phraseIndexDiscontinuity
    } else if evidence.startBar != expectedBar {
      reason = .barDiscontinuity
    } else if phraseCount.addingReportingOverflow(1).overflow
      || barCount.addingReportingOverflow(evidence.barCount).overflow
      || expectedPhraseIndex.addingReportingOverflow(1).overflow
      || expectedBar.addingReportingOverflow(evidence.barCount).overflow
    {
      reason = .counterOverflow
    } else {
      reason = nil
    }
    if let reason {
      unavailableReason = reason
      return .unavailable(reason)
    }

    var candidate = self
    candidate.apply(evidence)
    self = candidate
    return .accepted
  }

  package var report: LongHorizonEffectDoseReport {
    let reason = unavailableReason ?? (barCount == 0 ? .noObservations : nil)
    return LongHorizonEffectDoseReport(
      schemaVersion: LongHorizonEffectDoseSchema.schemaVersion,
      schemaIdentifier: LongHorizonEffectDoseSchema.schemaIdentifier,
      availability: reason == nil ? .available : .unavailable,
      unavailableReason: reason,
      qualificationStatus: "unavailable",
      qualificationReason: LongHorizonEffectDoseSchema.qualificationReason,
      rootSeed: rootSeed,
      phraseCount: phraseCount,
      barCount: barCount,
      families: zip(LongHorizonEffectFamily.allCases, states).map {
        family, state in
        LongHorizonEffectFamilyReport(
          family: family,
          eligibleBarCount: state.eligible,
          activeBarCount: state.active,
          activationCount: state.activations,
          tailOnlyBarCount: state.tailOnly,
          recoveryCount: state.recoveries,
          maximumActiveRunBars: state.maximumActiveRun,
          lastActiveBar: state.lastActiveBar,
          wetBarOccupancy: barCount == 0
            ? 0 : Double(state.active) / Double(barCount),
          minimumInactiveGapBars: state.minimumInactiveGap,
          maximumInactiveGapBars: state.maximumInactiveGap,
          meanInactiveGapBars: state.inactiveGapCount == 0
            ? nil : Double(state.inactiveGapSum) / Double(state.inactiveGapCount),
          meanReturnToSourceDB: state.relationshipCount == 0
            ? nil : state.relationshipSum / Double(state.relationshipCount),
          maximumReturnToSourceDB: state.maximumRelationship
        )
      },
      recentSentences: recentSentences
    )
  }

  private mutating func apply(_ evidence: LongHorizonEffectDosePhraseEvidence) {
    phraseCount += 1
    barCount += evidence.barCount
    expectedPhraseIndex += 1
    expectedBar += evidence.barCount
    if let sentence = evidence.realizedSentence {
      recentSentences.append(sentence)
      if recentSentences.count > LongHorizonEffectDoseSchema.sentenceHistoryCapacity {
        recentSentences.removeFirst(
          recentSentences.count - LongHorizonEffectDoseSchema.sentenceHistoryCapacity
        )
      }
    }
    for bar in evidence.bars {
      for (index, family) in LongHorizonEffectFamily.allCases.enumerated() {
        let observed = bar.state(for: family)
        var state = states[index]
        if observed.eligible { state.eligible += 1 }
        if observed.active {
          state.active += 1
          state.lastActiveBar = bar.bar
          if !state.previousActive {
            state.activations += 1
            if state.seenActive && state.currentInactiveGap > 0 {
              let gap = state.currentInactiveGap
              state.minimumInactiveGap = min(
                state.minimumInactiveGap ?? gap, gap
              )
              state.maximumInactiveGap = max(
                state.maximumInactiveGap ?? gap, gap
              )
              state.inactiveGapSum += gap
              state.inactiveGapCount += 1
            }
          }
          state.currentInactiveGap = 0
          state.currentActiveRun += 1
          state.maximumActiveRun = max(
            state.maximumActiveRun, state.currentActiveRun
          )
          state.seenActive = true
        } else {
          if state.previousActive { state.recoveries += 1 }
          state.currentActiveRun = 0
          if state.seenActive { state.currentInactiveGap += 1 }
        }
        if observed.tailOnly { state.tailOnly += 1 }
        if let relationship = observed.returnToSourceDB {
          state.relationshipSum += relationship
          state.relationshipCount += 1
          state.maximumRelationship = max(
            state.maximumRelationship ?? relationship,
            relationship
          )
        }
        state.previousActive = observed.active
        states[index] = state
      }
    }
  }
}

extension PreparedAutonomousPhrase {
  package var longHorizonEffectDoseEvidence: LongHorizonEffectDosePhraseEvidence? {
    LongHorizonEffectDosePhraseEvidence.make(prepared: self)
  }
}
