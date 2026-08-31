import Foundation

package enum LongHorizonEffectSentenceSchema {
  package static let schemaVersion = 1
  package static let schemaIdentifier =
    "autotechno-long-horizon-effect-sentence.v1"
}

package enum LongHorizonEffectSentenceCapability: String, Codable, Sendable {
  case gatedPercussionEcho = "gated-percussion-echo"
  case anticipationSwell = "anticipation-swell"
}

package enum LongHorizonEffectSentenceFunction: String, Codable, Sendable {
  case callResponse = "call-response"
  case turnaround
}

package enum LongHorizonEffectSentencePriority: String, Codable, Sendable {
  case supporting
  case foreground
}

/// One phrase-scale semantic sentence already present in the resolved score.
/// It annotates existing source/return geometry; it never creates an event,
/// effect permission, return bus, or renderer choice.
package struct LongHorizonEffectSentence: Codable, Equatable, Sendable {
  package let schemaVersion: Int
  package let schemaIdentifier: String
  package let phraseIndex: Int
  package let phraseKind: AutonomousPhraseKind
  package let sourceBar: Int
  package let sourceVoice: String
  package let sourceStep: Int
  package let answerStartStep: Int
  package let answerEndStep: Int
  package let arrangementGesture: String
  package let capability: LongHorizonEffectSentenceCapability
  package let function: LongHorizonEffectSentenceFunction
  package let attentionPriority: LongHorizonEffectSentencePriority

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case schemaIdentifier
    case phraseIndex
    case phraseKind
    case sourceBar
    case sourceVoice
    case sourceStep
    case answerStartStep
    case answerEndStep
    case arrangementGesture
    case capability
    case function
    case attentionPriority
  }

  package static func resolving(
    phraseIndex: Int,
    phraseKind: AutonomousPhraseKind,
    resolvedBars: [ResolvedPerformanceBar]
  ) -> LongHorizonEffectSentence? {
    var selected: (priority: Int, sentence: LongHorizonEffectSentence)?
    for resolved in resolvedBars {
      guard let articulation = resolved.percussionEchoTexture,
        let source =
          PercussionEchoTextureResolver
          .eligibleSourceEvents(in: resolved.ensemble)
          .first(where: { $0.step == articulation.inputStep })
      else {
        continue
      }
      let capability: LongHorizonEffectSentenceCapability
      let function: LongHorizonEffectSentenceFunction
      let attentionPriority: LongHorizonEffectSentencePriority
      let priority: Int
      switch articulation.relation {
      case .gatedEcho:
        capability = .gatedPercussionEcho
        function = .callResponse
        attentionPriority = .supporting
        priority = 1
      case .anticipationSwell:
        capability = .anticipationSwell
        function = .turnaround
        attentionPriority = .foreground
        priority = 2
      case .spatialDust:
        // The held dust bed is world cadence, not a phrase-scale call/answer
        // sentence. Existing foreground/supporting sentence ownership stays
        // with the two bounded special relations above.
        continue
      }
      let candidate = LongHorizonEffectSentence(
        phraseIndex: phraseIndex,
        phraseKind: phraseKind,
        sourceBar: resolved.performance.bar,
        sourceVoice: source.voice.rawValue,
        sourceStep: source.step,
        answerStartStep: articulation.outputStartStep,
        answerEndStep: articulation.outputEndStep,
        arrangementGesture: resolved.arrangementGesture.rawValue,
        capability: capability,
        function: function,
        attentionPriority: attentionPriority
      )
      if selected == nil || priority > (selected?.priority ?? 0) {
        selected = (priority, candidate)
      }
    }
    return selected?.sentence
  }

  package func isConsistent(
    phraseIndex: Int,
    phraseKind: AutonomousPhraseKind,
    resolvedBars: [ResolvedPerformanceBar]
  ) -> Bool {
    self
      == Self.resolving(
        phraseIndex: phraseIndex,
        phraseKind: phraseKind,
        resolvedBars: resolvedBars
      )
  }

  private init(
    phraseIndex: Int,
    phraseKind: AutonomousPhraseKind,
    sourceBar: Int,
    sourceVoice: String,
    sourceStep: Int,
    answerStartStep: Int,
    answerEndStep: Int,
    arrangementGesture: String,
    capability: LongHorizonEffectSentenceCapability,
    function: LongHorizonEffectSentenceFunction,
    attentionPriority: LongHorizonEffectSentencePriority
  ) {
    schemaVersion = LongHorizonEffectSentenceSchema.schemaVersion
    schemaIdentifier = LongHorizonEffectSentenceSchema.schemaIdentifier
    self.phraseIndex = phraseIndex
    self.phraseKind = phraseKind
    self.sourceBar = sourceBar
    self.sourceVoice = sourceVoice
    self.sourceStep = sourceStep
    self.answerStartStep = answerStartStep
    self.answerEndStep = answerEndStep
    self.arrangementGesture = arrangementGesture
    self.capability = capability
    self.function = function
    self.attentionPriority = attentionPriority
  }

  package init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
    phraseIndex = try container.decode(Int.self, forKey: .phraseIndex)
    phraseKind = try container.decode(AutonomousPhraseKind.self, forKey: .phraseKind)
    sourceBar = try container.decode(Int.self, forKey: .sourceBar)
    sourceVoice = try container.decode(String.self, forKey: .sourceVoice)
    sourceStep = try container.decode(Int.self, forKey: .sourceStep)
    answerStartStep = try container.decode(Int.self, forKey: .answerStartStep)
    answerEndStep = try container.decode(Int.self, forKey: .answerEndStep)
    arrangementGesture = try container.decode(String.self, forKey: .arrangementGesture)
    capability = try container.decode(
      LongHorizonEffectSentenceCapability.self,
      forKey: .capability
    )
    function = try container.decode(
      LongHorizonEffectSentenceFunction.self,
      forKey: .function
    )
    attentionPriority = try container.decode(
      LongHorizonEffectSentencePriority.self,
      forKey: .attentionPriority
    )
    let expectedFunction: LongHorizonEffectSentenceFunction =
      capability == .gatedPercussionEcho ? .callResponse : .turnaround
    let expectedPriority: LongHorizonEffectSentencePriority =
      capability == .gatedPercussionEcho ? .supporting : .foreground
    guard schemaVersion == LongHorizonEffectSentenceSchema.schemaVersion,
      schemaIdentifier == LongHorizonEffectSentenceSchema.schemaIdentifier,
      phraseIndex >= 0,
      sourceBar >= 0,
      EnsembleVoice(rawValue: sourceVoice) != nil,
      ArrangementGesture(rawValue: arrangementGesture) != nil,
      (0..<16).contains(sourceStep),
      answerStartStep > sourceStep,
      answerEndStep > answerStartStep,
      answerEndStep <= 16,
      function == expectedFunction,
      attentionPriority == expectedPriority
    else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: container.codingPath,
          debugDescription: "Unsupported or inconsistent long-horizon effect sentence"
        )
      )
    }
  }
}
