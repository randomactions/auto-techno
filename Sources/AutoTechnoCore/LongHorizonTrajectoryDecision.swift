import Foundation

/// Core-owned contract for one exact policy decision made from reduced
/// trajectory evidence. DSP owns evaluation; Core owns the future musical
/// boundary at which a bounded action may become canonical.
package enum LongHorizonTrajectoryDecisionSchema {
  package static let schemaVersion = 1
  package static let schemaIdentifier =
    "autotechno-long-horizon-trajectory-decision.v1"
}

package enum LongHorizonTrajectoryDecisionAction: String, Codable, Sendable {
  case preserve
  case recover
}

/// These reasons mirror interpretable policy dimensions without importing DSP
/// policy types into Core. They remain independent and canonically ordered.
package enum LongHorizonTrajectoryDecisionReason: String, CaseIterable,
  Codable, Sendable
{
  case qualified
  case identity
  case duration
  case semanticPeriodicity = "semantic-periodicity"
  case permanentPeak = "permanent-peak"
  case recoveryStarvation = "recovery-starvation"
  case identityRecall = "identity-recall"
  case dramaticDebt = "dramatic-debt"
  case capabilityFatigue = "capability-fatigue"
  case operatorConsequence = "operator-consequence"
  case effectFatigue = "effect-fatigue"
}

package struct LongHorizonTrajectoryDecision: Codable, Equatable, Sendable {
  package let schemaVersion: Int
  package let schemaIdentifier: String
  package let rootSeed: UInt64
  package let policyVersion: String
  package let evidenceSchema: String
  package let evidenceFingerprint: String
  package let observedThroughPhraseIndex: Int
  package let observedThroughBar: Int
  package let targetPhraseIndex: Int
  package let targetBar: Int
  package let action: LongHorizonTrajectoryDecisionAction
  package let reasons: [LongHorizonTrajectoryDecisionReason]
  package let fingerprint: String

  package init(
    rootSeed: UInt64,
    policyVersion: String,
    evidenceSchema: String,
    evidenceFingerprint: String,
    observedThroughPhraseIndex: Int,
    observedThroughBar: Int,
    action: LongHorizonTrajectoryDecisionAction,
    reasons: [LongHorizonTrajectoryDecisionReason]
  ) {
    let orderedReasons = LongHorizonTrajectoryDecisionReason.allCases.filter(
      Set(reasons).contains)
    schemaVersion = LongHorizonTrajectoryDecisionSchema.schemaVersion
    schemaIdentifier = LongHorizonTrajectoryDecisionSchema.schemaIdentifier
    self.rootSeed = rootSeed
    self.policyVersion = policyVersion
    self.evidenceSchema = evidenceSchema
    self.evidenceFingerprint = evidenceFingerprint
    self.observedThroughPhraseIndex = observedThroughPhraseIndex
    self.observedThroughBar = observedThroughBar
    targetPhraseIndex =
      observedThroughPhraseIndex == Int.max
      ? Int.max : observedThroughPhraseIndex + 1
    targetBar = observedThroughBar
    self.action = action
    self.reasons = orderedReasons
    fingerprint = Self.makeFingerprint(
      rootSeed: rootSeed,
      policyVersion: policyVersion,
      evidenceSchema: evidenceSchema,
      evidenceFingerprint: evidenceFingerprint,
      observedThroughPhraseIndex: observedThroughPhraseIndex,
      observedThroughBar: observedThroughBar,
      targetPhraseIndex: targetPhraseIndex,
      targetBar: targetBar,
      action: action,
      reasons: orderedReasons)
  }

  package var isComplete: Bool {
    let actionMatchesReasons =
      switch action {
      case .preserve:
        reasons == [.qualified]
      case .recover:
        !reasons.isEmpty && !reasons.contains(.qualified)
      }
    return schemaVersion == LongHorizonTrajectoryDecisionSchema.schemaVersion
      && schemaIdentifier
        == LongHorizonTrajectoryDecisionSchema.schemaIdentifier
      && !policyVersion.isEmpty && !evidenceSchema.isEmpty
      && Self.isFingerprint(evidenceFingerprint)
      && observedThroughPhraseIndex >= 0
      && observedThroughPhraseIndex < Int.max
      && observedThroughBar >= 0
      && targetPhraseIndex == observedThroughPhraseIndex + 1
      && targetBar == observedThroughBar
      && reasons
        == LongHorizonTrajectoryDecisionReason.allCases.filter(
          Set(reasons).contains)
      && actionMatchesReasons
      && fingerprint
        == Self.makeFingerprint(
          rootSeed: rootSeed,
          policyVersion: policyVersion,
          evidenceSchema: evidenceSchema,
          evidenceFingerprint: evidenceFingerprint,
          observedThroughPhraseIndex: observedThroughPhraseIndex,
          observedThroughBar: observedThroughBar,
          targetPhraseIndex: targetPhraseIndex,
          targetBar: targetBar,
          action: action,
          reasons: reasons)
  }

  package func isApplicable(
    rootSeed: UInt64,
    phraseIndex: Int,
    bar: Int
  ) -> Bool {
    isComplete && self.rootSeed == rootSeed
      && targetPhraseIndex == phraseIndex && targetBar == bar
  }

  package init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let decoded = try container.decode(Decoded.self)
    self = LongHorizonTrajectoryDecision(
      rootSeed: decoded.rootSeed,
      policyVersion: decoded.policyVersion,
      evidenceSchema: decoded.evidenceSchema,
      evidenceFingerprint: decoded.evidenceFingerprint,
      observedThroughPhraseIndex: decoded.observedThroughPhraseIndex,
      observedThroughBar: decoded.observedThroughBar,
      action: decoded.action,
      reasons: decoded.reasons)
    guard schemaVersion == decoded.schemaVersion,
      schemaIdentifier == decoded.schemaIdentifier,
      targetPhraseIndex == decoded.targetPhraseIndex,
      targetBar == decoded.targetBar,
      reasons == decoded.reasons,
      fingerprint == decoded.fingerprint,
      isComplete
    else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unsupported or inconsistent trajectory decision")
    }
  }

  private struct Decoded: Codable {
    let schemaVersion: Int
    let schemaIdentifier: String
    let rootSeed: UInt64
    let policyVersion: String
    let evidenceSchema: String
    let evidenceFingerprint: String
    let observedThroughPhraseIndex: Int
    let observedThroughBar: Int
    let targetPhraseIndex: Int
    let targetBar: Int
    let action: LongHorizonTrajectoryDecisionAction
    let reasons: [LongHorizonTrajectoryDecisionReason]
    let fingerprint: String
  }

  private static func makeFingerprint(
    rootSeed: UInt64,
    policyVersion: String,
    evidenceSchema: String,
    evidenceFingerprint: String,
    observedThroughPhraseIndex: Int,
    observedThroughBar: Int,
    targetPhraseIndex: Int,
    targetBar: Int,
    action: LongHorizonTrajectoryDecisionAction,
    reasons: [LongHorizonTrajectoryDecisionReason]
  ) -> String {
    var hasher = LongHorizonTrajectoryDecisionHasher()
    hasher.combine(LongHorizonTrajectoryDecisionSchema.schemaIdentifier)
    hasher.combine(rootSeed)
    hasher.combine(policyVersion)
    hasher.combine(evidenceSchema)
    hasher.combine(evidenceFingerprint)
    hasher.combine(observedThroughPhraseIndex)
    hasher.combine(observedThroughBar)
    hasher.combine(targetPhraseIndex)
    hasher.combine(targetBar)
    hasher.combine(action.rawValue)
    for reason in reasons { hasher.combine(reason.rawValue) }
    return hasher.fingerprint
  }

  private static func isFingerprint(_ value: String) -> Bool {
    value.count == 16
      && value.utf8.allSatisfy { byte in
        (48...57).contains(byte) || (97...102).contains(byte)
      }
  }
}

private struct LongHorizonTrajectoryDecisionHasher {
  private var value: UInt64 = 14_695_981_039_346_656_037

  mutating func combine(_ value: UInt64) {
    combine(String(value))
  }

  mutating func combine(_ value: Int) {
    combine(String(value))
  }

  mutating func combine(_ value: String) {
    for byte in value.utf8 {
      self.value ^= UInt64(byte)
      self.value &*= 1_099_511_628_211
    }
    self.value ^= 0xFF
    self.value &*= 1_099_511_628_211
  }

  var fingerprint: String {
    let raw = String(value, radix: 16)
    return String(repeating: "0", count: max(0, 16 - raw.count)) + raw
  }
}
