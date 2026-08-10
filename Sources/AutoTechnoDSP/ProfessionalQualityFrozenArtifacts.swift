import Foundation

/// Validated, non-reconstructable development artifacts generated from the
/// complete representative-rate journey bank. Loading these artifacts does not
/// activate paired rendering or alter the shipping autonomous runtime.
package struct ProfessionalQualityFrozenArtifacts: Sendable {
    package static let profileResource = "professional-quality-profile-v1"
    package static let adversarialResource =
        "professional-quality-adversarial-suite-v1"
    package static let expectedProfileFingerprint = "c52545b5641e6cfb"
    package static let expectedAdversarialSuiteFingerprint = "2340017ec6c59440"

    package let profile: ProfessionalQualityCalibrationProfile
    package let adversarialSuite: ProfessionalQualityAdversarialSuiteReport
    package let policy: ProfessionalQualityDevelopmentPolicy

    package init(profileData: Data, adversarialSuiteData: Data) throws {
        let profile = try ProfessionalQualityCalibrationProfile
            .decodeDeterministicJSON(profileData)
        let adversarialSuite = try ProfessionalQualityAdversarialSuiteReport
            .decodeDeterministicJSON(adversarialSuiteData)
        let policy = try ProfessionalQualityDevelopmentPolicy(
            profile: profile,
            adversarialSuite: adversarialSuite
        )
        self.profile = profile
        self.adversarialSuite = adversarialSuite
        self.policy = policy
    }

    package static func load() throws -> Self {
        guard let profileURL = Bundle.module.url(
            forResource: profileResource,
            withExtension: "json"
        ), let adversarialURL = Bundle.module.url(
            forResource: adversarialResource,
            withExtension: "json"
        ) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let artifacts = try Self(
            profileData: Data(contentsOf: profileURL),
            adversarialSuiteData: Data(contentsOf: adversarialURL)
        )
        guard artifacts.profile.fingerprint == expectedProfileFingerprint,
              artifacts.adversarialSuite.fingerprint ==
                expectedAdversarialSuiteFingerprint else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return artifacts
    }
}
