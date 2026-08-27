import Foundation

/// Immutable qualification artifacts for the last calibrated canonical
/// engine. Loading validates their identities and then rejects them when their
/// engine no longer matches `QualityQualificationContract.engineVersion`.
package struct ProfessionalQualityPrimaryArtifacts: Sendable {
    package static let profileResource =
        "professional-quality-primary-profile-v18"
    package static let adversarialResource =
        "professional-quality-primary-adversarial-suite-v18"
    package static let holdoutResource =
        "professional-quality-primary-holdout-v18"
    package static let expectedProfileFingerprint = "110a3db78e64df40"
    package static let expectedAdversarialSuiteFingerprint =
        "d1bf279a4cd021b2"
    package static let expectedHoldoutQualificationFingerprint =
        "72f08ccf5d7504da"

    package let profile: ProfessionalQualityCalibrationProfile
    package let adversarialSuite: ProfessionalQualityAdversarialSuiteReport
    package let holdoutQualification: ProfessionalQualityHoldoutQualification
    package let evaluator: ProfessionalQualityPrimaryEvaluator

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
        let evaluator = try ProfessionalQualityPrimaryEvaluator(
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

    package static func containsBundledResource(named name: String) -> Bool {
        Bundle.module.url(forResource: name, withExtension: "json") != nil
    }

    /// SwiftPM text resources retain the repository's final line feed. Remove
    /// only that packaging byte before enforcing exact deterministic JSON; any
    /// other whitespace or content change still fails canonical decoding.
    private static func canonicalResourceData(_ data: Data) -> Data {
        guard data.last == 0x0A else { return data }
        return data.dropLast()
    }
}
