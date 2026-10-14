import AutoTechnoCore
import Foundation
import Testing

@testable import AutoTechnoDSP

@Suite("Long-horizon score-owned energy coordination")
struct LongHorizonEnergyCoordinationTests {
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
    #expect(AutonomousTypedFingerprint.plan(fallback) == "d65fb6874c05376d")
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
    #expect(state.memory.longHorizon.fingerprint == "311f55d31923c807")
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
