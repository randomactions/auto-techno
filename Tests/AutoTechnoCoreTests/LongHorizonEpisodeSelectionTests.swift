import AutoTechnoCore
import Foundation
import Testing

@Suite("Long-horizon episode selection")
struct LongHorizonEpisodeSelectionTests {
  @Test("Every eligible episode operator selects one existing phrase kind")
  func eligibleOperatorsSelectCanonicalVocabulary() throws {
    let cases: [(LongHorizonEpisodeOperator, AutonomousPhraseKind)] = [
      (.maintain, .lock),
      (.rise, .contrast),
      (.recover, .majorBreak),
      (.reframe, .contrast),
      (.payoff, .energyRelease),
      (.recall, .identityReturn),
    ]

    for (operatorKind, expectedKind) in cases {
      let state = try state(
        operatorKind: operatorKind,
        eligibleAtBar: 0,
        openDebt: operatorKind == .payoff
      )
      let plan = AutonomousSessionDirector(rootSeed: 48_291).plan(from: state)

      #expect(plan.kind == expectedKind)
      #expect(plan.longHorizonSelection.phraseKind == expectedKind)
      #expect(plan.longHorizonSelection.operatorKind == operatorKind)
      #expect(
        plan.longHorizonSelection.episodeID == state.memory.longHorizon.currentEpisode.id)
      #expect(plan.longHorizonSelection.reason == .episodeOperator)
    }
  }

  @Test("A payoff without canonical debt establishes one before spending it")
  func payoffEstablishesThenPaysCanonicalDebt() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    var state = try state(
      operatorKind: .payoff,
      eligibleAtBar: 0,
      openDebt: false
    )

    let establishment = director.plan(from: state)
    #expect(establishment.kind == .contrast)
    #expect(establishment.longHorizonSelection.reason == .payoffDebtEstablishment)
    #expect(establishment.openedDebt != nil)
    state.advancePlanning(using: establishment)

    let payoff = director.plan(from: state)
    #expect(payoff.kind == .energyRelease)
    #expect(payoff.longHorizonSelection.reason == .episodeOperator)
    #expect(payoff.longHorizonSelection.operatorKind == .payoff)
    #expect(!payoff.paidDebtIDs.isEmpty)
  }

  @Test("Minimum hold protects reserved payoff and recall events")
  func minimumHoldProtectsRareEvents() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    let payoffState = try state(
      operatorKind: .payoff,
      phraseIndex: 0,
      totalBars: 200,
      eligibleAtBar: 512,
      openDebt: true
    )
    let recallState = try state(
      operatorKind: .recall,
      phraseIndex: 5,
      totalBars: 0,
      eligibleAtBar: 128,
      openDebt: false
    )

    let reservedPayoff = director.plan(from: payoffState)
    let reservedRecall = director.plan(from: recallState)

    #expect(reservedPayoff.kind == .lock)
    #expect(reservedPayoff.longHorizonSelection.reason == .reservedPayoff)
    #expect(reservedRecall.kind == .lock)
    #expect(reservedRecall.longHorizonSelection.reason == .reservedRecall)
  }

  @Test("Invalid hierarchy context uses the one conservative fallback")
  func invalidContextFallsBackConservatively() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    let state = try state(
      operatorKind: .rise,
      phraseIndex: 0,
      totalBars: 4,
      eligibleAtBar: 0,
      openDebt: false,
      continuationBar: 0
    )

    let plan = director.plan(from: state)
    let wrongDirectorPlan = AutonomousSessionDirector(rootSeed: 48_292)
      .plan(from: state)
    #expect(plan.longHorizonSelection.reason == .conservativeFallback)
    #expect(plan.longHorizonSelection.episodeID == nil)
    #expect(plan.longHorizonSelection.operatorKind == nil)
    #expect(wrongDirectorPlan.longHorizonSelection.reason == .conservativeFallback)
  }

  @Test("Identical complete context replays selection and plan exactly")
  func selectionReplaysExactly() throws {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    let state = try state(
      operatorKind: .recover,
      eligibleAtBar: 0,
      openDebt: false
    )

    let first = director.plan(from: state)
    let replay = director.plan(from: state)
    let encoded = try JSONEncoder().encode(first.longHorizonSelection)
    let decoded = try JSONDecoder().decode(
      LongHorizonPhraseSelection.self,
      from: encoded
    )
    let unsupported = try encodedSelection(
      first.longHorizonSelection,
      replacing: "schemaIdentifier",
      with: "autotechno-long-horizon-selection.v999"
    )
    #expect(first == replay)
    #expect(first.longHorizonSelection == replay.longHorizonSelection)
    #expect(first.longHorizonSelection.schemaVersion == 1)
    #expect(
      first.longHorizonSelection.schemaIdentifier
        == "autotechno-long-horizon-selection.v1")
    #expect(decoded == first.longHorizonSelection)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        LongHorizonPhraseSelection.self,
        from: unsupported
      )
    }
  }

  @Test("Four hours fulfill every operator with scarce payoff and prompt recovery")
  func canonicalJourneyHasCausalOperatorConsequences() {
    let director = AutonomousSessionDirector(rootSeed: 48_291)
    var state = director.initialState()
    var fulfilledOperators: [LongHorizonEpisodeOperator] = []
    var completedPayoffs = 0
    var completedRecoveries = 0
    var arcIndicesWithPayoff: Set<Int> = []
    var awaitingRecoveryAfterPayoff = false
    var maximumPayoffToRecoveryGap = 0
    var payoffCompletedAtBar: Int?

    while state.memory.totalBars < 7_800 {
      let episode = state.memory.longHorizon.currentEpisode
      let plan = director.plan(from: state)
      let incomingDebts = state.memory.openDebts

      if plan.longHorizonSelection.reason == .episodeOperator {
        fulfilledOperators.append(episode.operatorKind)
        switch episode.operatorKind {
        case .rise:
          #expect(plan.kind == .contrast)
          #expect(plan.openedDebt != nil)
        case .payoff:
          #expect(!incomingDebts.isEmpty)
          #expect(plan.kind == .energyRelease)
          #expect(!plan.paidDebtIDs.isEmpty)
        case .recover:
          #expect(plan.kind == .majorBreak)
        case .maintain, .reframe, .recall:
          break
        }
      }

      state.advancePlanning(using: plan)
      let completed = state.memory.longHorizon.currentEpisode.id != episode.id
      guard completed else { continue }

      switch episode.operatorKind {
      case .payoff:
        completedPayoffs += 1
        arcIndicesWithPayoff.insert(episode.arcIndex)
        awaitingRecoveryAfterPayoff = true
        payoffCompletedAtBar = state.memory.totalBars
        #expect(state.memory.longHorizon.currentEpisode.operatorKind == .recover)
      case .recover where awaitingRecoveryAfterPayoff:
        completedRecoveries += 1
        if let payoffCompletedAtBar {
          maximumPayoffToRecoveryGap = max(
            maximumPayoffToRecoveryGap,
            state.memory.totalBars - payoffCompletedAtBar
          )
        }
        awaitingRecoveryAfterPayoff = false
        payoffCompletedAtBar = nil
      case .maintain, .rise, .recover, .reframe, .recall:
        break
      }
    }

    print(
      "LONG_HORIZON_SELECTION_4H "
        + "fulfilled=\(fulfilledOperators.count) "
        + "payoffs=\(completedPayoffs) recoveries=\(completedRecoveries) "
        + "payoffArcs=\(arcIndicesWithPayoff.count) "
        + "maxPayoffRecoveryBars=\(maximumPayoffToRecoveryGap)"
    )
    #expect(Set(fulfilledOperators) == Set(LongHorizonEpisodeOperator.allCases))
    #expect(completedPayoffs > 0)
    #expect(completedPayoffs == arcIndicesWithPayoff.count)
    #expect(completedRecoveries == completedPayoffs)
    #expect(!awaitingRecoveryAfterPayoff)
    #expect(
      maximumPayoffToRecoveryGap
        <= LongHorizonContinuationSchema.maximumEpisodeMacros * 16 + 15)
  }
}

private func state(
  operatorKind: LongHorizonEpisodeOperator,
  phraseIndex: Int = 0,
  totalBars: Int = 0,
  eligibleAtBar: Int,
  openDebt: Bool,
  continuationBar: Int? = nil
) throws -> AutonomousSessionState {
  let continuation = try continuation(
    operatorKind: operatorKind,
    phraseIndex: phraseIndex,
    nextExpectedBar: continuationBar ?? totalBars,
    minimumHoldUntilBar: eligibleAtBar
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
    ]
    : []
  return AutonomousSessionState(
    rootSeed: 48_291,
    phraseIndex: phraseIndex,
    memory: TemporalMusicalMemory(
      totalBars: totalBars,
      openDebts: debts,
      longHorizon: continuation
    )
  )
}

private func continuation(
  operatorKind: LongHorizonEpisodeOperator,
  phraseIndex: Int,
  nextExpectedBar: Int,
  minimumHoldUntilBar: Int
) throws -> LongHorizonContinuationState {
  let initial = LongHorizonContinuationState.initial(
    rootSeed: 48_291,
    startingPhraseIndex: phraseIndex,
    startingBar: nextExpectedBar
  )
  let encoded = try JSONEncoder().encode(initial)
  guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
    var episode = object["currentEpisode"] as? [String: Any]
  else {
    throw DecodingError.dataCorrupted(
      .init(
        codingPath: [],
        debugDescription: "Expected continuation JSON object"
      ))
  }
  episode["operatorKind"] = operatorKind.rawValue
  episode["target"] = try JSONSerialization.jsonObject(
    with: JSONEncoder().encode(
      LongHorizonContinuationState.target(for: operatorKind)))
  episode["startedAtBar"] = max(0, nextExpectedBar - 128)
  episode["minimumHoldUntilBar"] = minimumHoldUntilBar
  episode["dueByBar"] = max(minimumHoldUntilBar + 128, nextExpectedBar + 128)
  object["currentEpisode"] = episode
  let mutated = try JSONSerialization.data(withJSONObject: object)
  return try JSONDecoder().decode(LongHorizonContinuationState.self, from: mutated)
}

private func encodedSelection(
  _ selection: LongHorizonPhraseSelection,
  replacing key: String,
  with value: Any
) throws -> Data {
  let encoded = try JSONEncoder().encode(selection)
  guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
    throw DecodingError.dataCorrupted(
      .init(
        codingPath: [],
        debugDescription: "Expected selection JSON object"
      ))
  }
  object[key] = value
  return try JSONSerialization.data(withJSONObject: object)
}
