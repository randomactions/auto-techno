import Foundation

/// Immutable calibration artifacts for the last calibrated canonical engine's
/// hour-scale professional policy. Loading validates exact identities and then
/// rejects them when their engine no longer matches the current contract.
package struct LongHorizonProfessionalPolicyArtifacts: Sendable {
  package static let profileResource =
    "long-horizon-professional-profile-v6"
  package static let adversarialResource =
    "long-horizon-adversarial-suite-v6"
  package static let holdoutResource =
    "long-horizon-holdout-v6"
  package static let expectedProfileFingerprint = "8d3aed3bd81f65a7"
  package static let expectedAdversarialFingerprint = "7e1ac366fd10f20b"
  package static let expectedHoldoutFingerprint = "0489b422f75c993a"

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
