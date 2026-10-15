import Foundation

/// Sole current continuous qualification identity. The retained v34 resources
/// bind the historical engine-v50 study; engine-v51 qualification is pending.
/// Explicit offline construction validates the same profile/adversarial/holdout
/// contract without activating transport or importing calibration banks.
package struct ProfessionalQualityPrimaryArtifacts: Sendable {
    package static let profileResource =
        "professional-quality-primary-profile-v34"
    package static let adversarialResource =
        "professional-quality-primary-adversarial-suite-v34"
    package static let holdoutResource =
        "professional-quality-primary-holdout-v34"
    // Fresh frozen 6d8d93a study: 40 development / 6 holdout trajectories,
    // both native rates, 34 adversarial cases and 84 accepted holdout observations.
    // The primary v32 policy/profile v33 contract remains intact. Those seals
    // cannot activate engine v51; fresh complete primary and Long Horizon
    // qualification must supply new authority without retagging old resources.
    package static let expectedProfileFingerprint: String? = nil
    package static let expectedAdversarialSuiteFingerprint: String? = nil
    package static let expectedHoldoutQualificationFingerprint: String? = nil

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
