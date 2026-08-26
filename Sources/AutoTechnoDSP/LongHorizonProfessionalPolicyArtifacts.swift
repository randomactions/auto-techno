import Foundation

/// Immutable calibration artifacts for the current canonical engine's
/// hour-scale professional policy. Loading validates exact identities, the
/// complete adversarial gate, and the disjoint accepted holdout before any
/// future-boundary adaptation may consume the policy.
package struct LongHorizonProfessionalPolicyArtifacts: Sendable {
  package static let profileResource =
    "long-horizon-professional-profile-v3"
  package static let adversarialResource =
    "long-horizon-adversarial-suite-v3"
  package static let holdoutResource =
    "long-horizon-holdout-v3"
  package static let expectedProfileFingerprint = "3c6b7dfeaa63bd76"
  package static let expectedAdversarialFingerprint = "a0a461a53be020fc"
  package static let expectedHoldoutFingerprint = "e23e50e67b2dccf7"

  package let profile: LongHorizonProfessionalProfile
  package let adversarial: LongHorizonAdversarialSuiteReport
  package let holdout: LongHorizonHoldoutQualification
  package let policy: LongHorizonProfessionalPolicy

  package init(
    profileData: Data,
    adversarialData: Data,
    holdoutData: Data
  ) throws {
    let profile = try LongHorizonProfessionalProfile.decodeDeterministicJSON(
      Self.canonicalResourceData(profileData))
    let adversarial =
      try LongHorizonAdversarialSuiteReport
      .decodeDeterministicJSON(Self.canonicalResourceData(adversarialData))
    let holdout =
      try LongHorizonHoldoutQualification
      .decodeDeterministicJSON(Self.canonicalResourceData(holdoutData))
    let policy = try LongHorizonProfessionalPolicy(
      profile: profile,
      adversarial: adversarial,
      holdout: holdout)
    self.profile = profile
    self.adversarial = adversarial
    self.holdout = holdout
    self.policy = policy
  }

  package static func load() throws -> Self {
    guard
      let profileURL = Bundle.module.url(
        forResource: profileResource,
        withExtension: "json"),
      let adversarialURL = Bundle.module.url(
        forResource: adversarialResource,
        withExtension: "json"),
      let holdoutURL = Bundle.module.url(
        forResource: holdoutResource,
        withExtension: "json")
    else {
      throw LongHorizonProfessionalPolicyError.invalidEvidence
    }
    let artifacts = try Self(
      profileData: Data(contentsOf: profileURL),
      adversarialData: Data(contentsOf: adversarialURL),
      holdoutData: Data(contentsOf: holdoutURL))
    guard
      artifacts.profile.fingerprint == expectedProfileFingerprint,
      artifacts.adversarial.fingerprint == expectedAdversarialFingerprint,
      artifacts.holdout.fingerprint == expectedHoldoutFingerprint
    else {
      throw LongHorizonProfessionalPolicyError.profileMismatch
    }
    return artifacts
  }

  package static func containsBundledResource(named name: String) -> Bool {
    Bundle.module.url(forResource: name, withExtension: "json") != nil
  }

  /// SwiftPM text resources retain the repository's final line feed. Remove
  /// only that packaging byte before enforcing exact deterministic JSON; any
  /// other whitespace or content change remains noncanonical.
  private static func canonicalResourceData(_ data: Data) -> Data {
    guard data.last == 0x0A else { return data }
    return data.dropLast()
  }
}
