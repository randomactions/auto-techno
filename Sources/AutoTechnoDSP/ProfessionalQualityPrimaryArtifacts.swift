import Foundation

/// Sole current continuous qualification identity. The v35 resource bundle
/// binds the complete fresh engine-v51 primary study; v34 remains historical.
/// Explicit offline construction validates the same profile/adversarial/holdout
/// contract without activating transport or importing calibration banks.
package struct ProfessionalQualityPrimaryArtifacts: Sendable {
    package static let profileResource =
        "professional-quality-primary-profile-v35"
    package static let adversarialResource =
        "professional-quality-primary-adversarial-suite-v35"
    package static let holdoutResource =
        "professional-quality-primary-holdout-v35"
    // Fresh frozen 9bd42d6 study: 40 development / 6 disjoint holdout
    // trajectories at both native rates, 34 adversarial cases and 84 accepted
    // holdout observations. The primary v32/profile v33 contract is unchanged.
    // These primary seals supply neither Long Horizon nor host admission.
    package static let expectedProfileFingerprint: String? = "267051f651dcfdca"
    package static let expectedAdversarialSuiteFingerprint: String? = "13b17b49e495d050"
    package static let expectedHoldoutQualificationFingerprint: String? = "d0be2dd73e33792b"

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
        guard let expectedProfileFingerprint,
              let expectedAdversarialSuiteFingerprint,
              let expectedHoldoutQualificationFingerprint,
              let profileURL = PackagedResourceBundle.current.url(
            forResource: profileResource,
            withExtension: "json"
        ), let adversarialURL = PackagedResourceBundle.current.url(
            forResource: adversarialResource,
            withExtension: "json"
        ), let holdoutURL = PackagedResourceBundle.current.url(
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
        PackagedResourceBundle.current.url(
            forResource: name,
            withExtension: "json"
        ) != nil
    }

    /// SwiftPM text resources retain the repository's final line feed. Remove
    /// only that packaging byte before enforcing exact deterministic JSON; any
    /// other whitespace or content change still fails canonical decoding.
    private static func canonicalResourceData(_ data: Data) -> Data {
        guard data.last == 0x0A else { return data }
        return data.dropLast()
    }
}
