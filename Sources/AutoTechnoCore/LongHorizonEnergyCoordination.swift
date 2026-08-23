import Foundation

/// Versioned provenance for the phrase-boundary projection of one episode
/// energy target into the existing canonical score. This is deliberately a
/// vector of relationships rather than a scalar intensity lane.
package enum LongHorizonEnergyCoordinationSchema {
  package static let schemaVersion = 1
  package static let schemaIdentifier =
    "autotechno-long-horizon-energy-coordination.v1"
}

package enum LongHorizonEnergyCoordinationReason: String, Codable, Sendable {
  case conservativeFallback = "conservative-fallback"
  case protectedRareEvent = "protected-rare-event"
  case episodeProgression = "episode-progression"
  case episodeFulfillment = "episode-fulfillment"
}

/// One immutable target selected before a phrase is authored. Each coordinate
/// is consumed by an existing score owner; an all-hold value must preserve the
/// exact pre-coordination score path.
package struct LongHorizonEnergyCoordination: Codable, Equatable, Sendable {
  package let schemaVersion: Int
  package let schemaIdentifier: String
  package let phraseIndex: Int
  package let startBar: Int
  package let phraseKind: AutonomousPhraseKind
  package let episodeID: UInt64?
  package let operatorKind: LongHorizonEpisodeOperator?
  package let selectionReason: LongHorizonPhraseSelectionReason
  package let reason: LongHorizonEnergyCoordinationReason
  package let target: LongHorizonEnergyTarget

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case schemaIdentifier
    case phraseIndex
    case startBar
    case phraseKind
    case episodeID
    case operatorKind
    case selectionReason
    case reason
    case target
  }

  package static func neutral(
    phraseIndex: Int,
    startBar: Int,
    phraseKind: AutonomousPhraseKind,
    selectionReason: LongHorizonPhraseSelectionReason = .conservativeFallback,
    episodeID: UInt64? = nil,
    operatorKind: LongHorizonEpisodeOperator? = nil,
    reason: LongHorizonEnergyCoordinationReason = .conservativeFallback
  ) -> LongHorizonEnergyCoordination {
    LongHorizonEnergyCoordination(
      phraseIndex: phraseIndex,
      startBar: startBar,
      phraseKind: phraseKind,
      episodeID: episodeID,
      operatorKind: operatorKind,
      selectionReason: selectionReason,
      reason: reason,
      target: .neutral
    )
  }

  package static func resolving(
    state: AutonomousSessionState,
    selection: LongHorizonPhraseSelection
  ) -> LongHorizonEnergyCoordination {
    let phraseIndex = state.phraseIndex
    let startBar = state.memory.totalBars
    let phraseKind = selection.phraseKind
    let continuation = state.memory.longHorizon
    guard continuation.isBound,
      continuation.rootSeed == state.rootSeed,
      continuation.nextExpectedPhraseIndex == phraseIndex,
      continuation.nextExpectedBar == startBar,
      selection.episodeID == continuation.currentEpisode.id,
      selection.operatorKind == continuation.currentEpisode.operatorKind,
      continuation.currentEpisode.target
        == LongHorizonContinuationState.target(
          for: continuation.currentEpisode.operatorKind
        )
    else {
      return .neutral(
        phraseIndex: phraseIndex,
        startBar: startBar,
        phraseKind: phraseKind,
        selectionReason: selection.reason
      )
    }

    let episode = continuation.currentEpisode
    switch selection.reason {
    case .conservativeFallback:
      return .neutral(
        phraseIndex: phraseIndex,
        startBar: startBar,
        phraseKind: phraseKind,
        selectionReason: selection.reason
      )
    case .reservedPayoff, .reservedRecall, .payoffDebtEstablishment:
      return .neutral(
        phraseIndex: phraseIndex,
        startBar: startBar,
        phraseKind: phraseKind,
        selectionReason: selection.reason,
        episodeID: episode.id,
        operatorKind: episode.operatorKind,
        reason: .protectedRareEvent
      )
    case .minimumHold:
      if episode.operatorKind == .payoff || episode.operatorKind == .recall {
        return .neutral(
          phraseIndex: phraseIndex,
          startBar: startBar,
          phraseKind: phraseKind,
          selectionReason: selection.reason,
          episodeID: episode.id,
          operatorKind: episode.operatorKind,
          reason: .protectedRareEvent
        )
      }
      return LongHorizonEnergyCoordination(
        phraseIndex: phraseIndex,
        startBar: startBar,
        phraseKind: phraseKind,
        episodeID: episode.id,
        operatorKind: episode.operatorKind,
        selectionReason: selection.reason,
        reason: .episodeProgression,
        target: episode.target
      )
    case .episodeOperator:
      return LongHorizonEnergyCoordination(
        phraseIndex: phraseIndex,
        startBar: startBar,
        phraseKind: phraseKind,
        episodeID: episode.id,
        operatorKind: episode.operatorKind,
        selectionReason: selection.reason,
        reason: .episodeFulfillment,
        target: episode.target
      )
    }
  }

  package func isConsistent(
    phraseIndex: Int,
    startBar: Int,
    phraseKind: AutonomousPhraseKind,
    selection: LongHorizonPhraseSelection
  ) -> Bool {
    guard self.phraseIndex == phraseIndex,
      self.startBar == startBar,
      self.phraseKind == phraseKind,
      selection.phraseKind == phraseKind,
      selectionReason == selection.reason
    else {
      return false
    }
    switch reason {
    case .conservativeFallback:
      return target.isNeutral && episodeID == nil && operatorKind == nil
        && selection.reason == .conservativeFallback
        && selection.episodeID == nil && selection.operatorKind == nil
    case .protectedRareEvent:
      let protectedSelection =
        selection.reason == .reservedPayoff
        || selection.reason == .reservedRecall
        || selection.reason == .payoffDebtEstablishment
        || (selection.reason == .minimumHold
          && (operatorKind == .payoff || operatorKind == .recall))
      return protectedSelection && target.isNeutral && episodeID == selection.episodeID
        && operatorKind == selection.operatorKind
    case .episodeProgression:
      return !target.isNeutral && episodeID == selection.episodeID
        && operatorKind == selection.operatorKind && selection.reason == .minimumHold
        && operatorKind != .payoff && operatorKind != .recall
        && operatorKind.map { target == LongHorizonContinuationState.target(for: $0) }
          == true
    case .episodeFulfillment:
      return !target.isNeutral && episodeID == selection.episodeID
        && operatorKind == selection.operatorKind && selection.reason == .episodeOperator
        && operatorKind.map { target == LongHorizonContinuationState.target(for: $0) }
          == true
    }
  }

  private init(
    phraseIndex: Int,
    startBar: Int,
    phraseKind: AutonomousPhraseKind,
    episodeID: UInt64?,
    operatorKind: LongHorizonEpisodeOperator?,
    selectionReason: LongHorizonPhraseSelectionReason,
    reason: LongHorizonEnergyCoordinationReason,
    target: LongHorizonEnergyTarget
  ) {
    schemaVersion = LongHorizonEnergyCoordinationSchema.schemaVersion
    schemaIdentifier = LongHorizonEnergyCoordinationSchema.schemaIdentifier
    self.phraseIndex = max(0, phraseIndex)
    self.startBar = max(0, startBar)
    self.phraseKind = phraseKind
    self.episodeID = episodeID
    self.operatorKind = operatorKind
    self.selectionReason = selectionReason
    self.reason = reason
    self.target = target
  }

  package init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    let schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
    let phraseIndex = try container.decode(Int.self, forKey: .phraseIndex)
    let startBar = try container.decode(Int.self, forKey: .startBar)
    let phraseKind = try container.decode(AutonomousPhraseKind.self, forKey: .phraseKind)
    let episodeID = try container.decodeIfPresent(UInt64.self, forKey: .episodeID)
    let operatorKind = try container.decodeIfPresent(
      LongHorizonEpisodeOperator.self,
      forKey: .operatorKind
    )
    let selectionReason = try container.decode(
      LongHorizonPhraseSelectionReason.self,
      forKey: .selectionReason
    )
    let reason = try container.decode(
      LongHorizonEnergyCoordinationReason.self,
      forKey: .reason
    )
    let target = try container.decode(LongHorizonEnergyTarget.self, forKey: .target)
    let canonicalTarget =
      operatorKind.map {
        target == LongHorizonContinuationState.target(for: $0)
      } == true
    let reasonIsConsistent =
      switch reason {
      case .conservativeFallback:
        target.isNeutral && episodeID == nil && operatorKind == nil
          && selectionReason == .conservativeFallback
      case .protectedRareEvent:
        target.isNeutral && episodeID != nil && operatorKind != nil
          && (selectionReason == .reservedPayoff
            || selectionReason == .reservedRecall
            || selectionReason == .payoffDebtEstablishment
            || (selectionReason == .minimumHold
              && (operatorKind == .payoff || operatorKind == .recall)))
      case .episodeProgression:
        !target.isNeutral && episodeID != nil && canonicalTarget
          && selectionReason == .minimumHold
          && operatorKind != .payoff && operatorKind != .recall
      case .episodeFulfillment:
        !target.isNeutral && episodeID != nil && canonicalTarget
          && selectionReason == .episodeOperator
      }
    guard schemaVersion == LongHorizonEnergyCoordinationSchema.schemaVersion,
      schemaIdentifier == LongHorizonEnergyCoordinationSchema.schemaIdentifier,
      phraseIndex >= 0,
      startBar >= 0,
      (episodeID == nil) == (operatorKind == nil),
      reasonIsConsistent
    else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: container.codingPath,
          debugDescription: "Unsupported or inconsistent long-horizon energy coordination"
        )
      )
    }
    self.schemaVersion = schemaVersion
    self.schemaIdentifier = schemaIdentifier
    self.phraseIndex = phraseIndex
    self.startBar = startBar
    self.phraseKind = phraseKind
    self.episodeID = episodeID
    self.operatorKind = operatorKind
    self.selectionReason = selectionReason
    self.reason = reason
    self.target = target
  }
}
