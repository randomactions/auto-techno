import Foundation

/// Current hour-scale artifact target. Missing v18 resources remain unavailable;
/// historical v16/v17 bytes cannot activate this policy. Exact qualification identities
/// are installed together only after the fresh native study passes.
package struct LongHorizonProfessionalPolicyArtifacts: Sendable {
  package static let profileResource =
    "long-horizon-professional-profile-v18"
  package static let adversarialResource =
    "long-horizon-adversarial-suite-v18"
  package static let holdoutResource =
    "long-horizon-holdout-v18"
  package static let expectedProfileFingerprint: String? = nil
  package static let expectedAdversarialFingerprint: String? = nil
  package static let expectedHoldoutFingerprint: String? = nil

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
    // An unqualified new family cannot inherit historical fingerprint authority,
    // even if files with the new target names appear in the resource bundle.
    guard let expectedProfileFingerprint,
      let expectedAdversarialFingerprint, let expectedHoldoutFingerprint
    else { throw LongHorizonProfessionalPolicyError.invalidEvidence }
    guard
      let profileURL = PackagedResourceBundle.current.url(
        forResource: profileResource,
        withExtension: "json"),
      let adversarialURL = PackagedResourceBundle.current.url(
        forResource: adversarialResource,
        withExtension: "json"),
      let holdoutURL = PackagedResourceBundle.current.url(
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
    PackagedResourceBundle.current.url(
      forResource: name,
      withExtension: "json") != nil
  }

  /// SwiftPM text resources retain the repository's final line feed. Remove
  /// only that packaging byte before enforcing exact deterministic JSON; any
  /// other whitespace or content change remains noncanonical.
  private static func canonicalResourceData(_ data: Data) -> Data {
    guard data.last == 0x0A else { return data }
    return data.dropLast()
  }
}
