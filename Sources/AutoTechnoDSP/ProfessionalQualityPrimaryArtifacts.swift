import Foundation

/// Sole current continuous qualification identity. The declared v33 bundle is
/// intentionally unavailable until the complete matched artifact set is installed.
/// Explicit offline construction validates the same profile/adversarial/holdout
/// contract without activating transport or importing calibration banks.
package struct ProfessionalQualityPrimaryArtifacts: Sendable {
    package static let profileResource =
        "professional-quality-primary-profile-v33"
    package static let adversarialResource =
        "professional-quality-primary-adversarial-suite-v33"
    package static let holdoutResource =
        "professional-quality-primary-holdout-v33"
    // Engine v49 changes canonical post-relocation wash ownership. The retained
    // d1259f3 engine-v48 study remains historical evidence, never a current seal.
    // Fresh complete native development/adversarial/holdout qualification is required.
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
