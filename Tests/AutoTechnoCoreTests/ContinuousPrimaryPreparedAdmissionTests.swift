import AutoTechnoCore
@testable import AutoTechnoTransport
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Continuous primary prepared admission", .serialized)
struct ContinuousPrimaryPreparedAdmissionTests {
    // Explicit retained-model control only. It does not install resources,
    // recertify the historical artifact's source, or label current qualification.
    @Test("Retained continuous model exercises actual calibrated prepared admission",
        .enabled(if: ProcessInfo.processInfo.environment["AUTOTECHNO_CONTINUOUS_PRIMARY_CONTROL_DIR"] != nil))
    @MainActor
    func retainedModelPreparedAdmission() throws {
        let root = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CONTINUOUS_PRIMARY_CONTROL_DIR"]))
        let artifacts = try ProfessionalQualityPrimaryArtifacts(
            profileData: Data(contentsOf: root.appendingPathComponent("offline-profile.json")),
            adversarialSuiteData: Data(contentsOf: root.appendingPathComponent("continuous-adversarial-suite.json")),
            holdoutQualificationData: Data(contentsOf: root.appendingPathComponent("continuous-holdout-qualification.json")))
        #expect(artifacts.profile.fingerprint == "4fb209bfb248d46b")
        #expect(artifacts.evaluator.requiresPreparedValidation)
        // A passing outer envelope from another measurement scope cannot
        // borrow this continuous profile's fingerprint to authorize admission.
        var mixedSuite = try #require(JSONSerialization.jsonObject(with:
            Data(contentsOf: root.appendingPathComponent("continuous-adversarial-suite.json"))) as? [String: Any])
        mixedSuite["schemaVersion"] = 22
        mixedSuite["suiteVersion"] = "autotechno-professional-quality-adversarial.v23"
        mixedSuite.removeValue(forKey: "sourceObservationVersion")
        let legacySuite = try JSONDecoder().decode(ProfessionalQualityAdversarialSuiteReport.self,
            from: JSONSerialization.data(withJSONObject: mixedSuite))
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryEvaluator(profile: artifacts.profile,
                adversarialSuite: legacySuite, holdoutQualification: artifacts.holdoutQualification)
        }
        var mixedHoldout = try #require(JSONSerialization.jsonObject(with:
            Data(contentsOf: root.appendingPathComponent("continuous-holdout-qualification.json"))) as? [String: Any])
        mixedHoldout["schemaVersion"] = 20
        mixedHoldout["qualificationVersion"] = "autotechno-professional-quality-holdout.v20"
        mixedHoldout["evaluatorVersion"] = "autotechno-professional-quality-holdout-evaluator.v20"
        mixedHoldout.removeValue(forKey: "sourceObservationVersion")
        let legacyHoldout = try JSONDecoder().decode(ProfessionalQualityHoldoutQualification.self,
            from: JSONSerialization.data(withJSONObject: mixedHoldout))
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryEvaluator(profile: artifacts.profile,
                adversarialSuite: artifacts.adversarialSuite, holdoutQualification: legacyHoldout)
        }
        struct Entry: Decodable { struct Planning: Decodable { let rootSeed: UInt64 }; let frozenPlanningEntry: Planning }
        let entry = try JSONDecoder().decode(Entry.self,
            from: Data(contentsOf: root.appendingPathComponent("development-ordinal-777.json")))
        let director = AutonomousSessionDirector(rootSeed: entry.frozenPlanningEntry.rootSeed)
        let state = director.initialState()
        let plan = director.plan(from: state)
        var rows: [[String: Any]] = []
        for rate in [44_100.0, 48_000.0] {
            let prepared = try #require(prepare(state: state, plan: plan, rate: rate,
                evaluator: ModelControlEvaluator(primary: artifacts.evaluator, state: state)).preparedPhrase)
            #expect(prepared.commitEligible)
            // Exercise the installed shared owner with the same retained model,
            // rather than only the evaluator's direct test wrapper. Operational
            // replay origin changes prepared identity, while PCM stays exact.
            let key = PhrasePreparationKey(sessionSeed: state.rootSeed, phraseIndex: state.phraseIndex,
                sampleRate: rate, channelCount: 2, routeRecovery: false,
                qualityRevision: state.quality.revision, qualityPolicyVersion: state.quality.policyVersion,
                qualityControllerFingerprint: state.quality.observedControllerStateFingerprint ?? state.quality.acceptedControllerStateFingerprint,
                routeGeneration: 0, incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
                incomingLiveMasterStateFingerprint: state.liveMasterHeadroom.fingerprint,
                pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil,
                liveTargetStartSample: nil)
            let request = PhrasePreparationRequest(key: key, sourceState: state, incomingLongHorizonState: nil,
                incomingRenderState: RenderState(), incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil, pendingLiveMasterBinding: nil)
            let shared = try #require(AutonomousPerformancePreparer.prepareDiagnosing(request: request,
                director: director, artifacts: artifacts, longHorizonArtifacts: nil).preparedPhrase)
            #expect(shared.prepared.commitEligible)
            #expect(shared.prepared.blocks == prepared.blocks)
            #expect(shared.prepared.audioPreflight.quality.sampleHash == prepared.audioPreflight.quality.sampleHash)
            #expect(shared.prepared.preparationReplayFingerprint == request.replayIdentity.fingerprint)
            #expect(shared.preparationChainResourceBudget?.sourceCount == 1)
            #expect(shared.retainedContinuations.isEmpty)
            let sharedProof = try #require(shared.prepared.preparedValidation)
            #expect(artifacts.evaluator.assessment(of: [sharedProof.observation]).accepted)
            let proof = try #require(prepared.preparedValidation)
            #expect(proof.hasRequiredMeasurements && proof.hasQualifiedContinuation)
            #expect(artifacts.evaluator.assessment(of: [proof.observation]).accepted)
            let unsupportedAssessment = artifacts.evaluator.assessment(
                of: [proof.observation.foreignRateChallenge()])
            #expect(unsupportedAssessment.availability == .unsupportedSampleRate)
            #expect(unsupportedAssessment.support == .sufficient)
            #expect(unsupportedAssessment.confidence == .unavailable)
            #expect(!unsupportedAssessment.accepted)
            #expect(artifacts.evaluator.assessment(of: prepared.selectedCandidateEvidence).availability == .invalidEvidence)
            let legacy = try ProfessionalQualityObservation(candidate: prepared.selectedCandidateEvidence,
                engineVersion: QualityQualificationContract.engineVersion, checkpoint: proof.observation.checkpoint)
            #expect(artifacts.evaluator.assessment(of: [legacy]).availability == .invalidEvidence)
            let attacked = try proof.observation.replacing(.maximumBoundaryDelta, with: 100)
            #expect(!artifacts.evaluator.assessment(of: [attacked]).accepted)
            rows.append(["sampleRate": rate, "sourceIdentity": proof.sourceIdentityFingerprint,
                "sampleHash": prepared.audioPreflight.quality.sampleHash,
                "requiredSuccessor": proof.requiresQualifiedSuccessor, "sourceCommitEligible": prepared.commitEligible])
        }
        let missing = try #require(prepare(state: state, plan: plan, rate: 44_100,
            evaluator: ModelControlEvaluator(primary: artifacts.evaluator, state: state, dropProof: true)).preparedPhrase)
        #expect(!missing.commitEligible && !missing.qualityDecision.isAcceptanceOutcome)
        #expect(missing.qualityContinuationState.acceptedEvidenceFingerprint == state.quality.acceptedEvidenceFingerprint)
        let unsupported = try #require(prepare(state: state, plan: plan, rate: 8_000,
            evaluator: ModelControlEvaluator(primary: artifacts.evaluator, state: state)).preparedPhrase)
        #expect(!unsupported.commitEligible && unsupported.qualityDecision.outcome == .qualificationUnavailable)
        let pendingDirector = AutonomousSessionDirector(rootSeed: 48_300)
        var pendingState = pendingDirector.initialState()
        for _ in 0..<21 { pendingState.advancePlanning(using: pendingDirector.plan(from: pendingState)) }
        let pending = try #require(prepare(state: pendingState, plan: pendingDirector.plan(from: pendingState),
            rate: 44_100, evaluator: ModelControlEvaluator(primary: artifacts.evaluator,
                state: pendingState, omitSuccessor: true)).preparedPhrase)
        #expect(!pending.commitEligible && pending.qualityDecision.outcome == .qualificationUnavailable)
        #expect(pending.preparedValidation?.hasRequiredMeasurements == false)
        let wire: [String: Any] = ["fixture": "continuous-primary-prepared-admission.v1", "rows": rows,
            "missingProofRefused": true, "unsupportedRateRefused": true, "unfinishedWindowsRefused": true,
            "legacyAndVectorOnlyAssessmentRefused": true, "metricAttackRefused": true, "mixedScopeArtifactsRefused": true,
            "sharedInstalledOwnerAdmissionExercised": true, "modelSource": "retained-7ef30ff-mechanical-only", "runtimeActivation": false]
        print(String(decoding: try JSONSerialization.data(withJSONObject: wire, options: [.sortedKeys]), as: UTF8.self))
    }

    private func prepare(state: AutonomousSessionState, plan: AutonomousPhrasePlan, rate: Double,
        evaluator: ModelControlEvaluator) -> AutonomousPhrasePreparationOutcome {
        var input = RenderState(); input.barIndex = plan.startBar
        return AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(plan: plan,
            sessionSeed: state.rootSeed, memory: state.memory, sampleRate: rate,
            incomingRenderState: input, incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil, incomingQualityState: state.quality, evaluator: evaluator,
            cancellationRequested: { false })
    }

    private struct ModelControlEvaluator: AutonomousCandidateEvaluating {
        let primary: ProfessionalQualityPrimaryEvaluator
        let state: AutonomousSessionState
        var dropProof = false
        var omitSuccessor = false
        var policyVersion: String { primary.policyVersion }
        var evaluatorVersion: String { primary.evaluatorVersion }
        var requiresPreparedValidation: Bool { primary.requiresPreparedValidation }
        func requestsHomeUpperTimbreCorrection(for candidate: AutonomousCandidateEvaluationVector) -> Bool {
            primary.requestsHomeUpperTimbreCorrection(for: candidate)
        }
        func terminalVerdict(selected: AutonomousCandidateEvaluationVector,
            transaction: AutonomousCandidateEvaluationTransaction) -> AutonomousCandidatePolicyVerdict {
            primary.terminalVerdict(selected: selected, transaction: transaction)
        }
        func preparedValidation(for preview: AutonomousCandidatePreparedPreview) -> AutonomousCandidatePreparedValidation? {
            if dropProof { return nil }
            var successor: PreparedAutonomousPhrase?
            if !omitSuccessor && (try? preview.requiresQualifiedSuccessorSupport()) == true {
                let next = state.advance(using: preview.plan, quality: preview.prospectiveQualityState,
                    liveMasterHeadroom: preview.prospectiveLiveMasterState)
                successor = AutonomousPhrasePreparer.prepareIfNotCancelled(
                    plan: AutonomousSessionDirector(rootSeed: next.rootSeed).plan(from: next),
                    sessionSeed: next.rootSeed, memory: next.memory,
                    sampleRate: preview.selectedCandidateEvidence.routeContinuation.sampleRate,
                    incomingRenderState: preview.endingRenderState, incomingGraphState: preview.endingGraphState,
                    previousGraph: preview.graph, incomingQualityState: next.quality,
                    evaluator: MechanicalSuccessor(policyVersion: policyVersion, evaluatorVersion: evaluatorVersion),
                    cancellationRequested: { false })
            }
            return primary.preparedValidation(for: preview, successor: successor)
        }
    }

    private struct MechanicalSuccessor: AutonomousCandidateEvaluating {
        let policyVersion: String; let evaluatorVersion: String
        var requiresPreparedValidation: Bool { true }
        func requestsHomeUpperTimbreCorrection(for candidate: AutonomousCandidateEvaluationVector) -> Bool { false }
        func terminalVerdict(selected: AutonomousCandidateEvaluationVector,
            transaction: AutonomousCandidateEvaluationTransaction) -> AutonomousCandidatePolicyVerdict {
            .init(outcome: .qualified, decisionBasis: .calibratedQuality, reasonCodes: [.candidateQualifiedV1])
        }
        func preparedValidation(for preview: AutonomousCandidatePreparedPreview) -> AutonomousCandidatePreparedValidation? {
            try? preview.assessingContinuous { _ in
                .init(outcome: .qualified, decisionBasis: .calibratedQuality, reasonCodes: [.candidateQualifiedV1])
            }
        }
    }
}
