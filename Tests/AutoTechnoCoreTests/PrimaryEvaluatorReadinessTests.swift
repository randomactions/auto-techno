import AutoTechnoCore
@testable import AutoTechnoDSP
@testable import AutoTechnoTransport
import Testing
import Foundation

@Suite("Single primary evaluator readiness", .serialized)
struct PrimaryEvaluatorReadinessTests {
    @Test("Modal evidence is non-compensable before the primary policy")
    func modalEvidencePrecedesPrimaryPolicy() {
        #expect(AutonomousCandidateEvaluationVector.schemaVersion == 43)
        #expect(AutonomousCandidateEvaluationTransaction.schemaVersion == 14)
        #expect(AutonomousPreparedCommitProvenance.schemaVersion == 3)
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 30)
        #expect(ProfessionalQualityObservation.schemaVersion == 21)
        #expect(ProfessionalQualityCalibrationProfile.schemaVersion == 22)
        #expect(ProfessionalQualityAdversarialSuiteReport.schemaVersion == 22)
        #expect(ProfessionalQualityHoldoutQualification.schemaVersion == 20)
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v32")
        #expect(ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier ==
                "autotechno-candidate-evaluator.primary-calibrated.v32")
        #expect(AutonomousCandidateCompletenessFailure.upperPercussionTailEvidence
            .rawValue == "upper-percussion-tail-evidence")
        #expect(AutonomousCandidateCompletenessFailure.modalPercussionEvidence
            .rawValue == "modal-percussion-evidence")
    }

    @Test("The maximum two-pass primary preparation fits the declared memory envelope")
    func representativeRateWorkingSetEnvelope() throws {
        #expect(QualityQualificationContract.maximumRenderPasses == 2)
        #expect(QualityQualificationContract.maximumCorrectionRenders == 1)

        for sampleRate in AutonomousPreparationResourceBudget.representativeSampleRates {
            let budget = try #require(AutonomousPreparationResourceBudget(
                sampleRate: sampleRate,
                barCount: QualityQualificationContract.maximumPhraseBars,
                renderPassCount: QualityQualificationContract.maximumRenderPasses
            ))
            #expect(budget.withinActivationBound)
            #expect(budget.peakWorkingByteCount <=
                    AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount)
        }
    }

    @Test("Historical bundled artifacts cannot activate any route under the current continuous policy")
    func bundledV30ArtifactsAreIneligible() {
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try historicalV30PrimaryArtifacts()
        }
        // Completed engine-v49/v50 studies retain historical authority only.
        // Neither resource revision may activate the engine-v51 owner.
        for revision in ["v33", "v34"] {
            #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
                let resources = PackagedResourceBundle.current
                let profile = try #require(resources.url(
                    forResource: "professional-quality-primary-profile-\(revision)", withExtension: "json"))
                let adversarial = try #require(resources.url(
                    forResource: "professional-quality-primary-adversarial-suite-\(revision)", withExtension: "json"))
                let holdout = try #require(resources.url(
                    forResource: "professional-quality-primary-holdout-\(revision)", withExtension: "json"))
                _ = try ProfessionalQualityPrimaryArtifacts(
                    profileData: Data(contentsOf: profile),
                    adversarialSuiteData: Data(contentsOf: adversarial),
                    holdoutQualificationData: Data(contentsOf: holdout))
            }
        }
        for sampleRate in [8_000.0, 12_000.0, 44_100.0, 48_000.0] {
            #expect(ProfessionalQualityPreparationEvaluator(
                sampleRate: sampleRate, artifacts: nil).availability == .artifactsUnavailable)
        }
    }

    @Test("Current qualified artifact seals determine host readiness")
    func installedPrimaryRetainsUnavailableLongHorizonHost() throws {
        // Preserve the exact completed v35 fixture independently of the current
        // installation. These admission checks never produce calibration data.
        let resources = PackagedResourceBundle.current
        let profileURL = try #require(resources.url(
            forResource: "professional-quality-primary-profile-v35", withExtension: "json"))
        let adversarialURL = try #require(resources.url(
            forResource: "professional-quality-primary-adversarial-suite-v35", withExtension: "json"))
        let holdoutURL = try #require(resources.url(
            forResource: "professional-quality-primary-holdout-v35", withExtension: "json"))
        let profileData = try Data(contentsOf: profileURL)
        let adversarialData = try Data(contentsOf: adversarialURL)
        let holdoutData = try Data(contentsOf: holdoutURL)
        // Decode the original bytes without admitting their historical engine.
        // The packaging LF is the only byte removed, as in the existing loader.
        let historicalProfile = try ProfessionalQualityCalibrationProfile
            .decodeDeterministicJSON(profileData.last == 0x0A ? profileData.dropLast() : profileData)
        let historicalAdversarial = try ProfessionalQualityAdversarialSuiteReport
            .decodeDeterministicJSON(adversarialData.last == 0x0A ? adversarialData.dropLast() : adversarialData)
        let historicalHoldout = try ProfessionalQualityHoldoutQualification
            .decodeDeterministicJSON(holdoutData.last == 0x0A ? holdoutData.dropLast() : holdoutData)
        #expect(historicalProfile.fingerprint == "267051f651dcfdca")
        #expect(historicalAdversarial.fingerprint == "13b17b49e495d050")
        #expect(historicalHoldout.fingerprint == "d0be2dd73e33792b")
        #expect(historicalProfile.engineVersion == "autotechno-canonical-engine.v51")
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryArtifacts(profileData: profileData,
                adversarialSuiteData: adversarialData, holdoutQualificationData: holdoutData)
        }

        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        #expect(artifacts.profile.fingerprint == ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint)
        #expect(artifacts.adversarialSuite.fingerprint == ProfessionalQualityPrimaryArtifacts.expectedAdversarialSuiteFingerprint)
        #expect(artifacts.holdoutQualification.fingerprint == ProfessionalQualityPrimaryArtifacts.expectedHoldoutQualificationFingerprint)
        #expect(artifacts.profile.engineVersion == QualityQualificationContract.engineVersion)
        #expect(artifacts.profile.sourceTrajectoryCount == 40)
        #expect(artifacts.adversarialSuite.cases.count == 34)
        #expect(artifacts.holdoutQualification.acceptedObservationCount == 84)
        #expect(artifacts.adversarialSuite.passed)
        #expect(artifacts.holdoutQualification.qualified)
        #expect(LongHorizonProfessionalPolicySchema.requiredPrimaryPolicyVersion ==
            artifacts.evaluator.policyVersion)
        for rate in [44_100.0, 48_000.0] {
            #expect(ProfessionalQualityPreparationEvaluator(sampleRate: rate,
                artifacts: artifacts).availability == .available)
        }
        let longSeals = [LongHorizonProfessionalPolicyArtifacts.expectedProfileFingerprint,
            LongHorizonProfessionalPolicyArtifacts.expectedAdversarialFingerprint,
            LongHorizonProfessionalPolicyArtifacts.expectedHoldoutFingerprint]
        if longSeals.allSatisfy({ $0 == nil }) {
            #expect(throws: LongHorizonProfessionalPolicyError.invalidEvidence) {
                try AutonomousPerformanceArtifactSet.load()
            }
        } else {
            // Partial, mismatched or missing installed evidence must fail here.
            #expect(longSeals.allSatisfy { $0 != nil })
            let admitted = try AutonomousPerformanceArtifactSet.load()
            #expect(admitted.primary.profile.fingerprint == artifacts.profile.fingerprint)
            #expect(admitted.longHorizon.profile.fingerprint == longSeals[0])
            #expect(admitted.longHorizon.adversarial.fingerprint == longSeals[1])
            #expect(admitted.longHorizon.holdout.fingerprint == longSeals[2])
            #expect(admitted.longHorizon.profile.primaryPolicyVersion == artifacts.evaluator.policyVersion)
            #expect(admitted.longHorizon.profile.sampleRates == artifacts.profile.sampleRates)
            #expect(admitted.longHorizon.adversarial.passed)
            #expect(admitted.longHorizon.holdout.qualified)
        }
    }

    @Test("Missing artifacts cannot activate the calibrated primary evaluator")
    func missingArtifactsStayUnavailable() {
        #expect(ProfessionalQualityPreparationEvaluator(
            sampleRate: 48_000,
            artifacts: nil
        ).availability == .artifactsUnavailable)
    }

    @Test("Cancellation before primary rendering produces no transaction")
    func primaryBoundaryCancellation() {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        let state = director.initialState()
        let prepared = AutonomousPhrasePreparer.prepareIfNotCancelled(
            plan: director.plan(from: state),
            sessionSeed: state.rootSeed,
            memory: state.memory,
            sampleRate: 48_000,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            evaluator: AcceptingPrimaryTestEvaluator(),
            cancellationRequested: { true }
        )
        #expect(prepared == nil)
    }

}
