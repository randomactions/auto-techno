import Foundation

/// Immutable qualification artifacts for the current canonical engine's
/// checkpoint-local paired-candidate judge. Loading these resources validates
/// both their deterministic identities and the adversarial gate; it does not
/// activate paired rendering or alter the shipping preparation overload.
package struct ProfessionalQualityPairedArtifacts: Sendable {
    package static let profileResource =
        "professional-quality-paired-profile-v1"
    package static let adversarialResource =
        "professional-quality-paired-adversarial-suite-v1"
    package static let expectedProfileFingerprint = "ffc8be201e9b8564"
    package static let expectedAdversarialSuiteFingerprint = "556508db468b3a64"

    package let profile: ProfessionalQualityCalibrationProfile
    package let adversarialSuite: ProfessionalQualityAdversarialSuiteReport
    package let evaluator: ProfessionalQualityPairedCandidateEvaluator

    package init(profileData: Data, adversarialSuiteData: Data) throws {
        let profile = try ProfessionalQualityCalibrationProfile
            .decodeDeterministicJSON(Self.canonicalResourceData(profileData))
        let adversarialSuite = try ProfessionalQualityAdversarialSuiteReport
            .decodeDeterministicJSON(Self.canonicalResourceData(
                adversarialSuiteData
            ))
        let evaluator = try ProfessionalQualityPairedCandidateEvaluator(
            profile: profile,
            adversarialSuite: adversarialSuite
        )
        self.profile = profile
        self.adversarialSuite = adversarialSuite
        self.evaluator = evaluator
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

    /// SwiftPM text resources retain the repository's final line feed. Remove
    /// only that packaging byte before enforcing exact deterministic JSON; any
    /// other whitespace or content change still fails canonical decoding.
    private static func canonicalResourceData(_ data: Data) -> Data {
        guard data.last == 0x0A else { return data }
        return data.dropLast()
    }
}
