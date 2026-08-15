import Foundation

/// Immutable qualification artifacts for the current canonical engine's
/// checkpoint-local paired-candidate judge. Loading these resources validates
/// both their deterministic identities and the adversarial gate; it does not
/// activate paired rendering or alter the shipping preparation overload.
package struct ProfessionalQualityPairedArtifacts: Sendable {
    package static let profileResource =
        "professional-quality-paired-profile-v2"
    package static let adversarialResource =
        "professional-quality-paired-adversarial-suite-v2"
    package static let holdoutResource =
        "professional-quality-paired-holdout-v1"
    package static let expectedProfileFingerprint = "4b55055d1904ead8"
    package static let expectedAdversarialSuiteFingerprint =
        "a34c3ba6acec9c2e"
    package static let expectedHoldoutQualificationFingerprint =
        "c333586ce068d5af"

    package let profile: ProfessionalQualityCalibrationProfile
    package let adversarialSuite: ProfessionalQualityAdversarialSuiteReport
    package let holdoutQualification: ProfessionalQualityHoldoutQualification
    package let evaluator: ProfessionalQualityPairedCandidateEvaluator

    package init(
        profileData: Data,
        adversarialSuiteData: Data,
        holdoutQualificationData: Data
    ) throws {
        let profile = try ProfessionalQualityCalibrationProfile
            .decodeDeterministicJSON(Self.canonicalResourceData(profileData))
        let adversarialSuite = try ProfessionalQualityAdversarialSuiteReport
            .decodeDeterministicJSON(Self.canonicalResourceData(
                adversarialSuiteData
            ))
        let holdoutQualification = try ProfessionalQualityHoldoutQualification
            .decodeDeterministicJSON(Self.canonicalResourceData(
                holdoutQualificationData
            ))
        let evaluator = try ProfessionalQualityPairedCandidateEvaluator(
            profile: profile,
            adversarialSuite: adversarialSuite,
            holdoutQualification: holdoutQualification
        )
        self.profile = profile
        self.adversarialSuite = adversarialSuite
        self.holdoutQualification = holdoutQualification
        self.evaluator = evaluator
    }

    package static func load() throws -> Self {
        guard let profileURL = Bundle.module.url(
            forResource: profileResource,
            withExtension: "json"
        ), let adversarialURL = Bundle.module.url(
            forResource: adversarialResource,
            withExtension: "json"
        ), let holdoutURL = Bundle.module.url(
            forResource: holdoutResource,
            withExtension: "json"
        ) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let artifacts = try Self(
            profileData: Data(contentsOf: profileURL),
            adversarialSuiteData: Data(contentsOf: adversarialURL),
            holdoutQualificationData: Data(contentsOf: holdoutURL)
        )
        guard artifacts.profile.fingerprint == expectedProfileFingerprint,
              artifacts.adversarialSuite.fingerprint ==
                expectedAdversarialSuiteFingerprint,
              artifacts.holdoutQualification.fingerprint ==
                expectedHoldoutQualificationFingerprint else {
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
