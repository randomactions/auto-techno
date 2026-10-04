import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Modal successor report join", .serialized)
struct ModalSuccessorReportJoinTests {
    @Test("Reproduce current frozen-study live baselines and construct its offline primary model",
        .enabled(if: ProcessInfo.processInfo.environment["AUTOTECHNO_VERIFY_EA5_NATIVE_LIVE_BASELINES"] == "1"))
    func verifyFreshNativePrimaryAndLiveReproducibility() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let study = root.appendingPathComponent("docs/local/reports/rms-trajectory-floor/fresh-qualification-ea5ea53")
        let artifacts = try ProfessionalQualityPrimaryArtifacts(
            profileData: Data(contentsOf: study.appendingPathComponent("offline-profile.json")),
            adversarialSuiteData: Data(contentsOf: study.appendingPathComponent("continuous-adversarial-suite.json")),
            holdoutQualificationData: Data(contentsOf: study.appendingPathComponent("continuous-holdout-qualification.json")))
        #expect(artifacts.profile.fingerprint == "4fb209bfb248d46b")
        #expect(artifacts.adversarialSuite.fingerprint == "e347aea9623bba24")
        #expect(artifacts.holdoutQualification.fingerprint == "57fc2efd43375934")
        let products = try LiveFeedbackTestSupport.renderContinuousLiveSourceProducts()
        let bound = try products.chain.continuousSourceObservations(
            attenuationReports: products.attenuationReports, attenuationSuccessor: products.attenuationSuccessor,
            recoveryReports: products.recoveryReports, recoverySuccessor: products.recoverySuccessor)
        let all = bound.attenuation + bound.recovery
        #expect(all.allSatisfy { $0.isComplete &&
            ProfessionalQualityProfileEvaluator.evaluate($0, against: artifacts.profile).accepted })
        let observations = [try #require(bound.attenuation.first), try #require(bound.recovery.first)]
        let fingerprints = try observations.map { observation in
            var sink = StreamingFNV1a()
            sink.domain("professional-quality-live-baseline.v1")
            sink.string(String(decoding: try observation.deterministicJSON(), as: UTF8.self))
            return fixedWidthFingerprintHex(sink.value)
        }
        #expect(fingerprints == artifacts.adversarialSuite.liveBaselineObservationFingerprints)
        #expect(Set(fingerprints).count == 2)
        let result: [String: Any] = ["schema": "autotechno-current-native-live-reproduction.v1",
            "qualifiedStudyHead": "ea5ea537a9359da47c6e9e7e75758cf9eddd74ba",
            "sourceScope": "post-study-working-tree-control-not-final-source-qualification",
            "primaryPolicyVersion": artifacts.evaluator.policyVersion,
            "liveBaselineFingerprints": fingerprints, "allFixedLabelsAccepted": all.allSatisfy {
                ProfessionalQualityProfileEvaluator.evaluate($0, against: artifacts.profile).accepted },
            "matchesQualifiedStudy": fingerprints == artifacts.adversarialSuite.liveBaselineObservationFingerprints,
            "archiveImport": false, "runtimeActivation": false, "fullRuntimeQualification": false]
        try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .prettyPrinted])
            .write(to: study.deletingLastPathComponent().appendingPathComponent("fresh-native-live-reproduction.json"), options: .atomic)
        print("current native live baselines: \(fingerprints); offline model construction succeeded; activation=false")
    }

    @Test("Continuous live challenge sources bind actual attenuation/recovery products and immediate successors")
    func continuousLiveAdversarialSourceBinding() throws {
        let products = try LiveFeedbackTestSupport.renderContinuousLiveSourceProducts()
        #expect(products.chain.isCausal)
        let bound = try products.chain.continuousSourceObservations(
            attenuationReports: products.attenuationReports,
            attenuationSuccessor: products.attenuationSuccessor,
            recoveryReports: products.recoveryReports,
            recoverySuccessor: products.recoverySuccessor)
        #expect(bound.attenuation.count == products.attenuationReports.count)
        #expect(bound.recovery.count == products.recoveryReports.count)
        #expect((bound.attenuation + bound.recovery).allSatisfy {
            $0.isComplete && $0.measurementScope == .continuousModalWindow
        })
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try products.chain.continuousSourceObservations(
                attenuationReports: [], attenuationSuccessor: products.attenuationSuccessor,
                recoveryReports: products.recoveryReports,
                recoverySuccessor: products.recoverySuccessor)
        }
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try products.chain.continuousSourceObservations(
                attenuationReports: products.recoveryReports,
                attenuationSuccessor: products.attenuationSuccessor,
                recoveryReports: products.recoveryReports,
                recoverySuccessor: products.recoverySuccessor)
        }
        #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
            try products.chain.continuousSourceObservations(
                attenuationReports: products.attenuationReports,
                attenuationSuccessor: products.recoverySuccessor,
                recoveryReports: products.recoveryReports,
                recoverySuccessor: products.recoverySuccessor)
        }
        for (reports, successor, candidate) in [
            (products.attenuationReports, products.attenuationSuccessor, products.chain.attenuation),
            (products.recoveryReports, products.recoverySuccessor, products.chain.recovery),
        ] {
            let applicable = CanonicalJourneyCheckpoint.applicable(
                phraseIndex: candidate.symbolic.phraseIndex,
                phraseKind: try #require(AutonomousPhraseKind(rawValue: candidate.symbolic.phraseKind)),
                chapterChanged: candidate.symbolic.chapterChanged
            )
            #expect(reports.map(\.checkpoint) == applicable)
            for source in reports {
                #expect(source.selectedCandidateEvidence == candidate)
                #expect(source.policyVersion == LiveFeedbackTestSupport.fingerprintQualifiedPolicyVersion)
                let receipt = try ProfessionalQualityModalSuccessorEvidence(source: source, successor: successor)
                let observation = try ProfessionalQualityObservation(continuousReport: source, successor: receipt)
                #expect(observation.isComplete)
                #expect(observation.measurementScope == .continuousModalWindow)
                #expect(observation.liveMaster == source.liveMaster)
                #expect(observation.continuousModalSource?.sourceIdentityFingerprint ==
                    ProfessionalQualityModalSuccessorEvidence.identity(source))
                #expect(receipt.successorIncomingRenderDSPFingerprint ==
                    source.commitProvenance.outgoingRenderDSPFingerprint)
                #expect(successor.plan.phraseIndex == candidate.symbolic.phraseIndex + 1)
                #expect(successor.incomingQualityState == source.outgoingState)
            }
        }
        let source = try #require(products.attenuationReports.first)
        #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
            try ProfessionalQualityModalSuccessorEvidence(source: source,
                successor: products.recoverySuccessor)
        }
    }

    private func historicalLegacyArtifacts() throws -> (
        profile: ProfessionalQualityCalibrationProfile,
        adversarialSuite: ProfessionalQualityAdversarialSuiteReport,
        holdoutQualification: ProfessionalQualityHoldoutQualification
    ) {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/AutoTechnoDSP/Resources")
        func data(_ name: String) throws -> Data {
            let resource = try Data(contentsOf: directory.appendingPathComponent(name + ".json"))
            return resource.last == 0x0A ? Data(resource.dropLast()) : resource
        }
        let profileData = try data("professional-quality-primary-profile-v30")
        let suiteData = try data("professional-quality-primary-adversarial-suite-v30")
        let holdoutData = try data("professional-quality-primary-holdout-v30")
        // Explicit historical fixtures remain readable for attacks on scope
        // bindings, but cannot become a current primary evaluator.
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryArtifacts(profileData: profileData,
                adversarialSuiteData: suiteData, holdoutQualificationData: holdoutData)
        }
        let profile = try JSONDecoder().decode(ProfessionalQualityCalibrationProfile.self, from: profileData)
        let suite = try JSONDecoder().decode(ProfessionalQualityAdversarialSuiteReport.self, from: suiteData)
        let holdout = try JSONDecoder().decode(ProfessionalQualityHoldoutQualification.self, from: holdoutData)
        #expect(profile.fingerprint == "45d94400c298892e")
        #expect(profile.measurementScope == .legacy && !profile.isComplete)
        #expect(!holdout.qualified)
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityCalibrationProfile.decodeDeterministicJSON(profileData)
        }
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityHoldoutQualification.decodeDeterministicJSON(holdoutData)
        }
        return (profile, suite, holdout)
    }

    @Test("Continuous metadata cannot relabel rejected historical legacy artifacts")
    func continuousQualificationScopeControls() throws {
        let artifacts = try historicalLegacyArtifacts()
        let suite = artifacts.adversarialSuite
        let holdout = artifacts.holdoutQualification
        #expect(suite.measurementScope == .legacy && suite.sourceObservationVersion == nil)
        #expect(holdout.measurementScope == .legacy && holdout.sourceObservationVersion == nil)
        #expect(suite.fingerprint == "a5070b55dd992655")
        #expect(holdout.fingerprint == "7169407cd746c0b6")
        #expect(suite.isBound(to: artifacts.profile))

        func changed(_ data: Data, values: [String: Any]) throws -> Data {
            var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            for (key, value) in values { object[key] = value }
            return try JSONSerialization.data(withJSONObject: object,
                options: [.sortedKeys, .withoutEscapingSlashes])
        }
        let continuousVersion = ProfessionalQualityMeasurementScope.continuousModalWindow.observationVersion
        let mixedSuiteData = try changed(suite.deterministicJSON(),
            values: ["sourceObservationVersion": continuousVersion])
        let mixedSuite = try JSONDecoder().decode(ProfessionalQualityAdversarialSuiteReport.self,
            from: mixedSuiteData)
        #expect(mixedSuite.measurementScope == nil && !mixedSuite.passed)
        #expect(!mixedSuite.isBound(to: artifacts.profile))
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityAdversarialSuiteReport.decodeDeterministicJSON(mixedSuiteData)
        }
        let mixedHoldoutData = try changed(holdout.deterministicJSON(),
            values: ["sourceObservationVersion": continuousVersion])
        let mixedHoldout = try JSONDecoder().decode(ProfessionalQualityHoldoutQualification.self,
            from: mixedHoldoutData)
        #expect(mixedHoldout.measurementScope == nil && !mixedHoldout.qualified)
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityHoldoutQualification.decodeDeterministicJSON(mixedHoldoutData)
        }

        // A coherent diagnostic envelope still cannot bind to the historical
        // legacy profile or authorize the primary runtime evaluator.
        let retiredSuiteData = try changed(suite.deterministicJSON(), values: [
            "sourceObservationVersion": continuousVersion, "schemaVersion": 23,
            "suiteVersion": "autotechno-professional-quality-adversarial.v24"])
        let retiredSuite = try JSONDecoder().decode(ProfessionalQualityAdversarialSuiteReport.self,
            from: retiredSuiteData)
        #expect(retiredSuite.measurementScope == nil && !retiredSuite.passed)
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityAdversarialSuiteReport.decodeDeterministicJSON(retiredSuiteData)
        }
        let continuousSuiteData = try changed(suite.deterministicJSON(), values: [
            "sourceObservationVersion": continuousVersion, "schemaVersion": 24,
            "suiteVersion": "autotechno-professional-quality-adversarial.v25"])
        let continuousSuite = try ProfessionalQualityAdversarialSuiteReport.decodeDeterministicJSON(
            continuousSuiteData)
        #expect(continuousSuite.measurementScope == .continuousModalWindow)
        #expect(!continuousSuite.isBound(to: artifacts.profile))
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryArtifacts(profileData: artifacts.profile.deterministicJSON(),
                adversarialSuiteData: continuousSuiteData,
                holdoutQualificationData: holdout.deterministicJSON())
        }
    }

    @Test("Continuous holdout metadata cannot authorize a historical legacy profile")
    func continuousHoldoutPrimaryScopeRejection() throws {
        let artifacts = try historicalLegacyArtifacts()
        var object = try #require(JSONSerialization.jsonObject(
            with: artifacts.holdoutQualification.deterministicJSON()) as? [String: Any])
        object["schemaVersion"] = 21
        object["qualificationVersion"] = "autotechno-professional-quality-holdout.v21"
        object["evaluatorVersion"] = "autotechno-professional-quality-holdout-evaluator.v21"
        object["sourceObservationVersion"] = ProfessionalQualityMeasurementScope.continuousModalWindow.observationVersion
        let data = try JSONSerialization.data(withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes])
        let diagnostic = try JSONDecoder().decode(ProfessionalQualityHoldoutQualification.self, from: data)
        #expect(diagnostic.measurementScope == .continuousModalWindow && !diagnostic.qualified)
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityHoldoutQualification.decodeDeterministicJSON(data)
        }
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryEvaluator(profile: artifacts.profile,
                adversarialSuite: artifacts.adversarialSuite, holdoutQualification: diagnostic)
        }
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try ProfessionalQualityPrimaryArtifacts(profileData: artifacts.profile.deterministicJSON(),
                adversarialSuiteData: artifacts.adversarialSuite.deterministicJSON(),
                holdoutQualificationData: data)
        }
    }

    @Test("Fixed actual live sources must be accepted by the preserved offline continuous fit")
    func continuousFixedLiveProfileAcceptance() throws {
        guard let path = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CONTINUOUS_LIVE_PROFILE_DIAGNOSTIC"] else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let profile = try ProfessionalQualityCalibrationProfile.decodeDeterministicJSON(data)
        #expect(profile.measurementScope == .continuousModalWindow)
        #expect(profile.fingerprint == "5fedcae807b0ce09")
        #expect(profile.sourceBankFingerprint == "39f157e5cbf2ba2a")
        let products = try LiveFeedbackTestSupport.renderContinuousLiveSourceProducts()
        let sources = try products.chain.continuousSourceObservations(
            attenuationReports: products.attenuationReports,
            attenuationSuccessor: products.attenuationSuccessor,
            recoveryReports: products.recoveryReports,
            recoverySuccessor: products.recoverySuccessor)
        var outcomes: [[String: Any]] = []
        var allAccepted = true
        for (role, observations) in [("attenuation", sources.attenuation),
                                     ("recovery", sources.recovery)] {
            for observation in observations {
                let verdict = ProfessionalQualityProfileEvaluator.evaluate(observation, against: profile)
                allAccepted = allAccepted && verdict.accepted
                outcomes.append(["role": role, "checkpoint": observation.checkpoint.rawValue,
                    "sampleRate": observation.sampleRate, "accepted": verdict.accepted,
                    "reasons": verdict.reasons.map(\.rawValue),
                    "failedMetrics": verdict.failedMetrics.map(\.rawValue)])
            }
        }
        let result: [String: Any] = ["fixture": "fixed-continuous-live-profile-acceptance.v1",
            "profileFingerprint": profile.fingerprint, "profileSource": "preserved9fd02fc-offline-fit",
            "allApplicableBaselinesAccepted": allAccepted, "outcomes": outcomes,
            "qualification": "unqualified-not-activated", "newFitClaimed": false]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result,
            options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
        #expect(allAccepted)
    }

    @Test("Frozen public score selection joins only the actual successor at all fixed rates")
    // This large detached fixture needs the main thread stack, matching existing calibration tests.
    @MainActor
    func actualSuccessorReportJoin() throws {
        var director = AutonomousSessionDirector(rootSeed: 48_291)
        let rates = [8_000.0, 44_100.0, 48_000.0]
        var initial = director.initialState()
        var selected: AutonomousPhrasePlan?
        for ordinal in 0..<64 {
            director = AutonomousSessionDirector(rootSeed: 48_291 + UInt64(ordinal))
            initial = director.initialState()
            for _ in 0..<128 {
                let plan = director.plan(from: initial)
                if let last = plan.resolvedBars.last,
                   last.modalPercussionArticulations.contains(where: { articulation in
                       rates.allSatisfy { rate in
                           let frames = Int((240 / AutonomousSessionDirector.bpm * rate).rounded())
                           let offset = VoiceRenderer.timingOffsetInSteps(for: .tunedTom,
                               step: articulation.step, dna: plan.dna)
                           let onset = Int(((Double(articulation.step) + offset) * Double(frames) / 16).rounded())
                           return frames - onset < Int(ceil(rate * 0.240))
                           }
                   }) { selected = plan; break }
                initial.advancePlanning(using: plan)
            }
            if selected != nil { break }
        }
        let plan = try #require(selected)
        var rows: [[String: Any]] = []
        var lowRateSuccessor: PreparedAutonomousPhrase?
        for rate in rates {
            var input = RenderState(); input.barIndex = plan.startBar
            let originResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
                plan: plan, sessionSeed: initial.rootSeed, memory: initial.memory, sampleRate: rate,
                incomingRenderState: input, incomingGraphState: GeneratedDSPContinuationState(),
                previousGraph: nil, incomingQualityState: initial.quality,
                evaluator: ProfessionalEvidenceOnlyEvaluator(), cancellationRequested: { false })
            let origin = try #require(originResult)
            let nextState = initial.advance(using: origin.plan, quality: origin.qualityContinuationState,
                liveMasterHeadroom: origin.liveMasterHeadroomContinuationState)
            let nextPlan = director.plan(from: nextState)
            let nextResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
                plan: nextPlan, sessionSeed: nextState.rootSeed, memory: nextState.memory, sampleRate: rate,
                incomingRenderState: origin.endingRenderState, incomingGraphState: origin.endingGraphState,
                previousGraph: origin.graph, incomingQualityState: nextState.quality,
                evaluator: ProfessionalEvidenceOnlyEvaluator(), cancellationRequested: { false })
            let next = try #require(nextResult)
            let source = try report(origin, label: "original")
            if let otherRate = lowRateSuccessor {
                #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                    try ProfessionalQualityModalSuccessorEvidence(source: source, successor: otherRate)
                }
            } else { lowRateSuccessor = next }
            let receipt = try ProfessionalQualityModalSuccessorEvidence(source: source, successor: next)
            #expect(receipt.successorIncomingRenderDSPFingerprint == origin.commitProvenance.outgoingRenderDSPFingerprint)
            let pending = try #require(source.selectedCandidateEvidence.modalPercussion.last?.continuousWindows).pending.count
            #expect(pending > 0)
            let before = try ProfessionalQualityContinuousModalWindowEvidence(report: source)
            let joined = try ProfessionalQualityContinuousModalWindowEvidence(report: source, successor: receipt)
            #expect(joined.isComplete && joined.schemaVersion == 2)
            #expect(joined.sourceEventCount == before.sourceEventCount)
            let originalObservation = try ProfessionalQualityObservation(report: source)
            let incompleteObservation = try ProfessionalQualityObservation(continuousReport: source)
            let continuousObservation = try ProfessionalQualityObservation(continuousReport: source, successor: receipt)
            #expect(continuousObservation.isComplete)
            #expect(continuousObservation.measurementScope == .continuousModalWindow)
            #expect(continuousObservation.schemaVersion == 23)
            #expect(continuousObservation.observationVersion ==
                ProfessionalQualityMeasurementContract.continuousModalObservationVersion)
            #expect(continuousObservation.continuousModalSource?.projection == joined)
            #expect(continuousObservation.continuousModalSource?.sourceIdentityFingerprint ==
                ProfessionalQualityModalSuccessorEvidence.identity(source))
            #expect(continuousObservation.modalWindowSupport == nil)
            // Runtime products share the original ledger and extraction path,
            // but retain their own identity instead of manufacturing fixtures.
            let preparedBefore = try ProfessionalQualityObservation(continuousPrepared: origin)
            let preparedObservation = try ProfessionalQualityObservation(
                continuousPrepared: origin, successor: next)
            let preparedReceipt = try ProfessionalQualityModalSuccessorEvidence(
                sourcePrepared: origin, successor: next)
            #expect(preparedObservation.isComplete)
            #expect(preparedObservation.measurementScope == .continuousModalWindow)
            #expect(preparedObservation.checkpoint == ProfessionalQualityObservation.primaryCheckpoint(
                for: origin.selectedCandidateEvidence))
            #expect(preparedBefore.measurementApplicability(.modalPercussionTailToBodyDBMean) == .unavailable)
            #expect(preparedObservation.continuousModalSource?.projection.tailBodySupport == joined.tailBodySupport)
            #expect(preparedObservation.continuousModalSource?.projection.attackBodySupport == joined.attackBodySupport)
            #expect(preparedObservation.continuousModalSource?.sourceIdentityFingerprint ==
                ProfessionalQualityModalSuccessorEvidence.identity(origin))
            #expect(preparedObservation.continuousModalSource?.sourceIdentityFingerprint !=
                continuousObservation.continuousModalSource?.sourceIdentityFingerprint)
            #expect(preparedReceipt.matches(origin) && !preparedReceipt.matches(source))
            #expect(receipt.matches(source) && !receipt.matches(origin))
            #expect(try ProfessionalQualityObservation(continuousPrepared: origin, successor: next) == preparedObservation)
            let preparedData = try preparedObservation.deterministicJSON()
            let preparedReceiptData = try preparedReceipt.deterministicJSON()
            #expect(try ProfessionalQualityObservation.decodeValidated(preparedData,
                prepared: origin, successor: next) == preparedObservation)
            #expect(try ProfessionalQualityModalSuccessorEvidence.decodeValidated(preparedReceiptData,
                sourcePrepared: origin, successor: next) == preparedReceipt)
            #expect(try ProfessionalQualityObservation.decodeValidated(preparedBefore.deterministicJSON(),
                prepared: origin) == preparedBefore)
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(ProfessionalQualityObservation.self, from: preparedData)
            }
            // Missing suffix coverage, substituted products, scope swaps,
            // noncanonical bytes, and changed metrics never reconstruct.
            for data in [preparedData, try continuousObservation.deterministicJSON(),
                         try preparedObservation.replacing(.maximumBoundaryDelta, with: 100).deterministicJSON(),
                         preparedData + Data([0x0a])] {
                #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                    try ProfessionalQualityObservation.decodeValidated(data, prepared: origin)
                }
            }
            for data in [try continuousObservation.deterministicJSON(),
                         try preparedObservation.replacing(.maximumBoundaryDelta, with: 100).deterministicJSON(),
                         preparedData + Data([0x0a])] {
                #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                    try ProfessionalQualityObservation.decodeValidated(data, prepared: origin, successor: next)
                }
            }
            for data in [try receipt.deterministicJSON(), preparedReceiptData + Data([0x0a])] {
                #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                    try ProfessionalQualityModalSuccessorEvidence.decodeValidated(data,
                        sourcePrepared: origin, successor: next)
                }
            }
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityObservation.decodeValidated(preparedData, prepared: next, successor: next)
            }
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityModalSuccessorEvidence.decodeValidated(preparedReceiptData,
                    sourcePrepared: next, successor: next)
            }
            #expect(throws: ProfessionalEvidenceReportBankError.invalidBounds) {
                try ProfessionalQualityObservation.decodeValidated(
                    Data(repeating: 0, count: ProfessionalEvidenceReportBank.maximumEncodedBytes + 1),
                    prepared: origin, successor: next)
            }
            #expect(throws: ProfessionalEvidenceReportBankError.invalidBounds) {
                try ProfessionalQualityModalSuccessorEvidence.decodeValidated(
                    Data(repeating: 0, count: ProfessionalQualityModalSuccessorEvidence.maximumEncodedBytes + 1),
                    sourcePrepared: origin, successor: next)
            }
            #expect(preparedObservation.liveMaster == continuousObservation.liveMaster)
            #expect(preparedObservation.upperPercussionTailSupport == continuousObservation.upperPercussionTailSupport)
            for metric in ProfessionalQualityMetric.allCases {
                #expect(preparedObservation[metric] == continuousObservation[metric])
            }
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityObservation(continuousPrepared: origin, successor: origin)
            }
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityContinuousModalWindowEvidence(prepared: origin, successor: receipt)
            }
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityContinuousModalWindowEvidence(report: source, successor: preparedReceipt)
            }
            if let otherRate = lowRateSuccessor, otherRate !== next {
                #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                    try ProfessionalQualityObservation(continuousPrepared: origin, successor: otherRate)
                }
            }
            #expect(!origin.commitEligible && !next.commitEligible)

            #expect(incompleteObservation.measurementApplicability(.modalPercussionTailToBodyDBMean) == .unavailable)
            #expect(incompleteObservation[.modalPercussionTailToBodyDBMean] == nil)
            for metric in ProfessionalQualityMetric.allCases where
                !ProfessionalQualityMeasurementContract.modalMetrics.contains(metric) {
                #expect(continuousObservation[metric] == originalObservation[metric])
            }
            let observationData = try continuousObservation.deterministicJSON()
            let rebuilt = try ProfessionalQualityObservation.decodeValidated(observationData,
                report: source, successor: receipt)
            #expect(rebuilt == continuousObservation)
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(ProfessionalQualityObservation.self, from: observationData)
            }
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityObservation.decodeValidated(observationData, report: source)
            }
            let challenged = try continuousObservation.replacing(.maximumBoundaryDelta, with: 100)
            #expect(challenged.continuousModalSource == continuousObservation.continuousModalSource)
            let liveReplaced = try continuousObservation.replacingLiveMaster(continuousObservation.liveMaster)
            #expect(liveReplaced == continuousObservation)
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityObservation.decodeValidated(challenged.deterministicJSON(),
                    report: source, successor: receipt)
            }
            for mutation in ["schema", "version", "source", "support", "omission", "scope"] {
                var wire = try #require(JSONSerialization.jsonObject(with: observationData) as? [String: Any])
                switch mutation {
                case "schema": wire["schemaVersion"] = 22
                case "version": wire["observationVersion"] = ProfessionalQualityObservation.observationVersion
                case "source":
                    var origin = wire["continuousModalSource"] as! [String: Any]
                    origin["sourceIdentityFingerprint"] = "0000000000000000"
                    wire["continuousModalSource"] = origin
                case "support":
                    var origin = wire["continuousModalSource"] as! [String: Any]
                    var projection = origin["projection"] as! [String: Any]
                    projection["sourceEventCount"] = 0
                    origin["projection"] = projection; wire["continuousModalSource"] = origin
                case "omission":
                    var metrics = wire["metrics"] as! [[String: Any]]
                    metrics.removeFirst(); wire["metrics"] = metrics
                    wire["sourceMetricCount"] = metrics.count
                default:
                    wire["modalWindowSupport"] = try JSONSerialization.jsonObject(with:
                        JSONEncoder().encode(ProfessionalQualityModalWindowEvidence(report: source)))
                }
                let altered = try JSONSerialization.data(withJSONObject: wire, options: [.sortedKeys, .withoutEscapingSlashes])
                #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                    try ProfessionalQualityObservation.decodeValidated(altered, report: source, successor: receipt)
                }
            }
            #expect(before.tailBodySupport.partialWindowEventCount + before.tailBodySupport.missingWindowEventCount == pending)
            #expect(joined.tailBodySupport.partialWindowEventCount + joined.tailBodySupport.missingWindowEventCount == 0)
            #expect(source.decision.outcome == .qualificationUnavailable && next.qualityDecision.outcome == .qualificationUnavailable)
            let data = try receipt.deterministicJSON()
            #expect(try ProfessionalQualityModalSuccessorEvidence.decodeValidated(data,
                source: source, successor: next) == receipt)
            let renamed = try report(origin, label: "retargeted-source")
            #expect(renamed.evidenceFingerprint == source.evidenceFingerprint)
            #expect(ProfessionalQualityModalSuccessorEvidence.identity(renamed) != receipt.sourceIdentityFingerprint)
            let renamedObservation = try ProfessionalQualityObservation(continuousReport: renamed)
            #expect(renamedObservation.continuousModalSource?.sourceIdentityFingerprint !=
                incompleteObservation.continuousModalSource?.sourceIdentityFingerprint)
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityObservation.decodeValidated(observationData, report: renamed, successor: receipt)
            }
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityObservation(continuousReport: renamed, successor: receipt)
            }
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityContinuousModalWindowEvidence(report: renamed, successor: receipt)
            }
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityModalSuccessorEvidence(source: source, successor: origin)
            }
            for field in ["successorIncomingRenderDSPFingerprint", "successorIncomingQualityFingerprint",
                          "successorPreviousGraphFingerprint", "routeGeneration", "sampleRate",
                          "sourceIdentityFingerprint", "successorIdentityFingerprint", "successorPlanFingerprint"] {
                var wire = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
                if field == "routeGeneration" { wire[field] = 1 }
                else if field == "sampleRate" { wire[field] = rate + 1 }
                else { wire[field] = "0000000000000000" }
                #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                    try ProfessionalQualityModalSuccessorEvidence.decodeValidated(
                        JSONSerialization.data(withJSONObject: wire, options: [.sortedKeys]), source: source, successor: next)
                }
            }
            for mutation in ["gap", "missing", "extra", "frames", "invalid", "overflow"] {
                #expect(throws: (any Error).self) {
                    var first = try #require(JSONSerialization.jsonObject(with:
                        JSONEncoder().encode(receipt.firstBar)) as? [String: Any])
                    var records = first["completed"] as! [[String: Any]]
                    let original = records.firstIndex { ($0["originBar"] as! Int) < (first["bar"] as! Int) }!
                    switch mutation {
                    case "gap": first["bar"] = (first["bar"] as! Int) + 1
                    case "missing": records.remove(at: original)
                    case "extra":
                        var extra = records[original]; extra["scoreEventIndex"] = 999; records.append(extra)
                    case "frames": records[original]["originFrameCount"] = (records[original]["originFrameCount"] as! Int) + 1
                    case "invalid": records[original]["observedFrameCount"] = 0
                    default: first["droppedRecordCount"] = 1
                    }
                    first["completed"] = records
                    let forged = try JSONDecoder().decode(ModalPercussionContinuousBarEvidence.self,
                        from: JSONSerialization.data(withJSONObject: first, options: [.sortedKeys]))
                    var ledger = try ModalPercussionObservationLedger(bars: source.selectedCandidateEvidence.modalPercussion.map {
                        try #require($0.continuousWindows)
                    })
                    try ledger.append(forged)
                }
            }
            for field in ["sourceIdentityFingerprint", "successorIdentityFingerprint", "successorSampleHash"] {
                var wire = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
                wire[field] = "0000000000000000"
                #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                    try ProfessionalQualityModalSuccessorEvidence.decodeValidated(
                        JSONSerialization.data(withJSONObject: wire, options: [.sortedKeys]), source: source, successor: next)
                }
            }
            if rate == 8_000 {
                for mismatch in ["inputDSP", "inputQuality", "priorGraph", "generation", "recovery"] {
                    var alteredInput = origin.endingRenderState
                    if mismatch == "inputDSP" { alteredInput.pulseEchoHighPassState += 0.00001 }
                    let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
                        plan: nextPlan, sessionSeed: nextState.rootSeed, memory: nextState.memory, sampleRate: rate,
                        incomingRenderState: alteredInput, incomingGraphState: origin.endingGraphState,
                        previousGraph: mismatch == "priorGraph" ? nil : origin.graph,
                        incomingQualityState: mismatch == "inputQuality" ? initial.quality : nextState.quality,
                        routeRecovery: mismatch == "recovery", routeGeneration: mismatch == "generation" ? 1 : 0,
                        evaluator: ProfessionalEvidenceOnlyEvaluator(), cancellationRequested: { false })
                    if let wrong = outcome.preparedPhrase {
                        #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                            try ProfessionalQualityModalSuccessorEvidence(source: source, successor: wrong)
                        }
                        #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                            try ProfessionalQualityObservation(continuousPrepared: origin, successor: wrong)
                        }
                    } else { #expect(outcome.failure != nil) }
                }
                // Real score checkpoints at one low-cost supported rate test bank
                // ownership only; this is not a calibration population or journey.
                let bank = try bankIncluding(source, director: director)
                let projections = try bank.continuousModalWindowFeatureReports(successors: [receipt])
                #expect(projections.count == CanonicalJourneyCheckpoint.allCases.count)
                #expect(projections.filter { $0.successorEvidenceFingerprint != nil } == [joined])
                #expect(throws: ProfessionalEvidenceReportBankError.duplicateReport) {
                    try bank.continuousModalWindowFeatureReports(successors: [receipt, receipt])
                }
                let unowned = try ProfessionalQualityModalSuccessorEvidence(source: renamed, successor: next)
                #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                    try bank.continuousModalWindowFeatureReports(successors: [unowned])
                }
            }
            rows.append(["sampleRate": rate, "pendingOriginalEvents": pending,
                "sourceEventCount": joined.sourceEventCount, "beforeTailPartial": before.tailBodySupport.partialWindowEventCount,
                "afterTailPartial": joined.tailBodySupport.partialWindowEventCount,
                "afterTailMissing": joined.tailBodySupport.missingWindowEventCount,
                "undefinedBodyEvents": joined.tailBodySupport.undefinedBodyEventCount,
                "receiptFingerprint": receipt.fingerprint,
                "preparedReceiptFingerprint": preparedReceipt.fingerprint,
                "preparedSourceIdentityFingerprint": ProfessionalQualityModalSuccessorEvidence.identity(origin),
                "preparedMeasurementsEqualReportMeasurements": preparedObservation.metrics == continuousObservation.metrics,
                "preparedCanonicalReconstructionPassed": true,
                "preparedTailMeasuredEventCount": preparedObservation.continuousModalSource!.projection.tailBodySupport.measuredEventCount,
                "qualification": "unavailable-not-activated"])
        }
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:
            ["fixture": "modal-successor-report-join.v1", "publicSeed": initial.rootSeed,
             "phraseIndex": plan.phraseIndex, "startBar": plan.startBar, "rows": rows], options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("Private prospective source admission requires actual complete and identity-bound successor evidence")
    @MainActor
    func preparedValidationAdmission() throws {
        let director = AutonomousSessionDirector(rootSeed: 48_300)
        var state = director.initialState()
        for _ in 0..<21 { state.advancePlanning(using: director.plan(from: state)) }
        let plan = director.plan(from: state)
        #expect(plan.phraseIndex == 21 && plan.startBar == 225)
        let originalState = state
        var rows: [[String: Any]] = []
        var cachedProof: AutonomousCandidatePreparedValidation?
        for rate in [8_000.0, 44_100.0, 48_000.0] {
            let control = PreparedValidationControl()
            let evaluator = PreparedValidationTestEvaluator(
                startingState: state, control: control, mode: .actualSuccessor)
            let first = try #require(prepareValidationSource(
                state: state, plan: plan, rate: rate, evaluator: evaluator).preparedPhrase)
            #expect(first.preparedValidationRequired && first.commitEligible)
            let proof = try #require(first.preparedValidation)
            #expect(proof.hasRequiredMeasurements && proof.hasQualifiedContinuation)
            #expect(proof.requiresQualifiedSuccessor)
            let successor = try #require(proof.qualifiedSuccessor)
            #expect(successor.commitEligible && successor.preparedValidationRequired)
            #expect(successor.preparedValidation?.requiresQualifiedSuccessor == false)
            #expect(successor.preparedValidation?.qualifiedSuccessor == nil)
            #expect(successor.plan.phraseIndex == first.plan.phraseIndex + 1)
            #expect(successor.incomingQualityState == first.qualityContinuationState)
            #expect(successor.selectedCandidateEvidence.routeContinuation.incomingRenderDSPFingerprint ==
                first.commitProvenance.outgoingRenderDSPFingerprint)
            #expect(try ProfessionalQualityObservation(continuousPrepared: first,
                successor: successor) == proof.observation)
            // Replaying accepted first-bar PCM does not continue the last bar's
            // unfinished source records. Never relabel that historical evidence.
            let sourceBars = try first.selectedCandidateEvidence.modalPercussion.map {
                try #require($0.continuousWindows)
            }
            let sourceLastBar = try #require(sourceBars.last)
            let repeatedFirstBar = try #require(sourceBars.first)
            #expect(!sourceLastBar.pending.isEmpty)
            #expect(repeatedFirstBar.incomingStateFingerprint != sourceLastBar.outgoingStateFingerprint)
            let repeatedIdentities = Set((repeatedFirstBar.completed + repeatedFirstBar.pending).map(\.identity))
            #expect(sourceLastBar.pending.allSatisfy { !repeatedIdentities.contains($0.identity) })
            #expect(throws: ProfessionalEvidenceReportBankError.incompleteEvidence) {
                var ledger = try ModalPercussionObservationLedger(bars: sourceBars)
                try ledger.append(repeatedFirstBar)
            }
            #expect(proof.sourceIdentityFingerprint == ProfessionalQualityModalSuccessorEvidence.identity(first))
            #expect(proof.observation.continuousModalSource?.projection.tailBodySupport.partialWindowEventCount == 0)
            #expect(first.qualityContinuationState.acceptanceProvenanceComplete)
            #expect(first.qualityContinuationState.revision == state.quality.revision + 1)
            #expect(first.candidateEvaluation.attempts.count == 1 && first.correctionRenderCount == 0)
            #expect(control.snapshot.calls == 1 && control.snapshot.probes == 1)
            #expect(control.snapshot.probeWasCommitEligible == true)
            #expect(control.snapshot.assessments == 1)
            let repeatControl = PreparedValidationControl()
            let repeated = try #require(prepareValidationSource(state: state, plan: plan, rate: rate,
                evaluator: PreparedValidationTestEvaluator(startingState: state,
                    control: repeatControl, mode: .actualSuccessor)).preparedPhrase)
            #expect(repeated.commitEligible)
            #expect(repeated.audioPreflight.quality.sampleHash == first.audioPreflight.quality.sampleHash)
            #expect(repeated.qualityContinuationState == first.qualityContinuationState)
            #expect(repeated.commitProvenance == first.commitProvenance)
            #expect(repeated.preparedValidation?.observation == proof.observation)
            #expect(repeated.preparedValidation?.sourceIdentityFingerprint == proof.sourceIdentityFingerprint)
            #expect(repeated.preparedValidation?.qualifiedSuccessor?.audioPreflight.quality.sampleHash ==
                successor.audioPreflight.quality.sampleHash)
            #expect(repeated.preparedValidation?.qualifiedSuccessor?.qualityContinuationState ==
                successor.qualityContinuationState)
            let advanced = state.advance(using: first.plan, quality: first.qualityContinuationState,
                liveMasterHeadroom: first.liveMasterHeadroomContinuationState)
            #expect(advanced.phraseIndex == state.phraseIndex + 1)
            #expect(advanced.quality == first.qualityContinuationState)
            #expect(state == originalState)
            if rate == 8_000 { cachedProof = proof }
            rows.append(["sampleRate": rate, "sourceIdentity": proof.sourceIdentityFingerprint,
                "sampleHash": first.audioPreflight.quality.sampleHash,
                "validationCalls": control.snapshot.calls, "probeRenders": control.snapshot.probes,
                "probeCommitEligible": control.snapshot.probeWasCommitEligible,
                "sourceCommitEligible": first.commitEligible, "qualification": "mechanical-only-not-installed"])
        }
        for mode in [PreparedValidationTestEvaluator.Mode.missingProof, .missingSuccessor, .unacceptedSuccessor, .reject] {
            let control = PreparedValidationControl()
            let source = try #require(prepareValidationSource(state: state, plan: plan, rate: 8_000,
                evaluator: PreparedValidationTestEvaluator(startingState: state,
                    control: control, mode: mode)).preparedPhrase)
            #expect(!source.commitEligible)
            #expect(source.qualityContinuationState.acceptedEvidenceFingerprint == state.quality.acceptedEvidenceFingerprint)
            #expect(!source.qualityDecision.isAcceptanceOutcome)
            #expect(control.snapshot.calls == 1)
            if mode == .unacceptedSuccessor {
                let proof = try #require(source.preparedValidation)
                #expect(proof.hasRequiredMeasurements && proof.requiresQualifiedSuccessor)
                #expect(!proof.hasQualifiedContinuation && proof.qualifiedSuccessor == nil)
                #expect(source.qualityDiagnosticDetails == ["prepared-validation=qualified-continuation-unavailable"])
                #expect(control.snapshot.assessments == 0 && control.snapshot.probes == 1)
                #expect(!control.snapshot.probeWasCommitEligible)
            }
            if mode == .missingSuccessor {
                #expect(control.snapshot.assessments == 0 && control.snapshot.probes == 0)
                #expect(source.preparedValidation?.hasRequiredMeasurements == false)
            }
        }
        let changed = prepareValidationSource(state: state, plan: plan, rate: 8_000,
            evaluator: PreparedValidationTestEvaluator(startingState: state,
                control: PreparedValidationControl(), mode: .changedAcceptedReason))
        #expect(changed.preparedPhrase == nil)
        #expect(changed.failure?.code == .preparedValidationMismatch)
        #expect(changed.failure?.details.contains("prepared-validation-source") == true)
        let foreign = try #require(prepareValidationSource(state: state, plan: plan, rate: 8_000,
            evaluator: PreparedValidationTestEvaluator(startingState: state,
                control: PreparedValidationControl(cached: cachedProof), mode: .foreignProof),
            routeGeneration: 1).preparedPhrase)
        #expect(!foreign.commitEligible && foreign.preparedValidation == nil)
        #expect(foreign.qualityDiagnosticDetails == ["prepared-validation=source-mismatch"])
        let cancelledControl = PreparedValidationControl()
        let cancelled = prepareValidationSource(state: state, plan: plan, rate: 8_000,
            evaluator: PreparedValidationTestEvaluator(startingState: state,
                control: cancelledControl, mode: .cancel))
        #expect(cancelled.preparedPhrase == nil && cancelled.failure?.code == .cancelled)
        #expect(cancelledControl.snapshot.calls == 1)
        let correctedControl = PreparedValidationControl()
        let corrected = try #require(prepareValidationSource(state: state, plan: plan, rate: 8_000,
            evaluator: PreparedValidationTestEvaluator(startingState: state,
                control: correctedControl, mode: .actualSuccessor, correct: true)).preparedPhrase)
        #expect(corrected.commitEligible && corrected.qualityDecision.outcome == .adjusted)
        #expect(corrected.candidateEvaluation.attempts.count == 2 && corrected.correctionRenderCount == 1)
        #expect(correctedControl.snapshot.calls == 1 && correctedControl.snapshot.probes == 1)
        let wire: [String: Any] = ["fixture": "private-prepared-validation-admission.v1",
            "rows": rows, "requiredProofMissingRefused": true, "sourceOnlySuffixRefused": true,
            "foreignProofRefused": true, "unacceptedSuccessorRefused": true,
            "qualifiedSuccessorRetained": true, "repeatCannotCompleteOriginalLedger": true,
            "acceptedQualityRebindingRefused": true,
            "cancelledBeforeAdmission": true, "adjustedTransactionBound": true,
            "qualification": "mechanical-only-not-installed"]
        print(String(decoding: try JSONSerialization.data(withJSONObject: wire, options: [.sortedKeys]), as: UTF8.self))
    }

    @Test("Private long-horizon projection uses the accepted reducer and seals exact source admission")
    @MainActor
    func preparedValidationLongHorizonProjection() throws {
        let rates = [8_000.0, 44_100.0, 48_000.0]
        let artifacts = try qualifiedArtifacts(sampleRates: rates)
        let policy = try LongHorizonProfessionalPolicy(profile: artifacts.profile,
            adversarial: artifacts.adversarial, holdout: artifacts.holdout)
        let director = AutonomousSessionDirector(rootSeed: 48_300)
        var state = director.initialState()
        for _ in 0..<21 { state.advancePlanning(using: director.plan(from: state)) }
        let plan = director.plan(from: state)
        let incoming = try #require(LongHorizonFutureAdaptationState(startingState: state, policy: policy))
        let incomingFingerprint = incoming.fingerprint
        var rows: [[String: Any]] = []
        var captured: LongHorizonProspectiveAdaptation?
        for rate in rates {
            let control = PreparedValidationControl()
            let source = try #require(prepareValidationSource(state: state, plan: plan, rate: rate,
                evaluator: PreparedValidationTestEvaluator(startingState: state, control: control,
                    mode: .actualSuccessor, longHorizonState: incoming, longHorizonPolicy: policy)).preparedPhrase)
            #expect(source.commitEligible)
            let projection = try #require(control.snapshot.projection)
            let admitted = try #require(projection.admittedUpdate(for: source,
                incomingState: state, incomingAdaptation: incoming, policy: policy))
            let observed = try #require(incoming.observing(prepared: source, incomingState: state, policy: policy))
            #expect(admitted.state.fingerprint == observed.state.fingerprint)
            #expect(admitted.decision == observed.decision)
            #expect(projection.sourceIdentityFingerprint == ProfessionalQualityModalSuccessorEvidence.identity(source))
            #expect(control.snapshot.signal == LongHorizonSignalPhraseEvidence.make(prepared: source))
            #expect(projection.projectedState.expectedPhraseIndex == state.phraseIndex + 1)
            #expect(projection.projectedState.expectedBar == plan.startBar + plan.barCount)
            #expect(incoming.fingerprint == incomingFingerprint)
            let successor = try #require(source.preparedValidation?.qualifiedSuccessor)
            let acceptedFuture = state.advance(using: source.plan, quality: source.qualityContinuationState,
                liveMasterHeadroom: source.liveMasterHeadroomContinuationState,
                longHorizonDecision: observed.decision)
            #expect(successor.plan == director.plan(from: acceptedFuture))
            if rate == 8_000 { captured = projection }
            rows.append(["sampleRate": rate, "sourceIdentity": projection.sourceIdentityFingerprint,
                "projectedStateFingerprint": projection.projectedState.fingerprint,
                "admittedMatchesObserved": true, "canonicalSuccessorPlanMatches": true])
        }
        let seal = try #require(captured)
        for mode in [PreparedValidationTestEvaluator.Mode.missingProof, .unacceptedSuccessor, .reject] {
            let source = try #require(prepareValidationSource(state: state, plan: plan, rate: 8_000,
                evaluator: PreparedValidationTestEvaluator(startingState: state,
                    control: PreparedValidationControl(), mode: mode)).preparedPhrase)
            #expect(!source.commitEligible && seal.admittedUpdate(for: source,
                incomingState: state, incomingAdaptation: incoming, policy: policy) == nil)
        }
        let otherRoute = try #require(prepareValidationSource(state: state, plan: plan, rate: 8_000,
            evaluator: PreparedValidationTestEvaluator(startingState: state,
                control: PreparedValidationControl(), mode: .actualSuccessor), routeGeneration: 1).preparedPhrase)
        #expect(otherRoute.commitEligible && seal.admittedUpdate(for: otherRoute,
            incomingState: state, incomingAdaptation: incoming, policy: policy) == nil)
        let wrongState = try #require(LongHorizonFutureAdaptationState(
            startingState: AutonomousSessionDirector(rootSeed: 90_909).initialState(), policy: policy))
        let sameSource = try #require(prepareValidationSource(state: state, plan: plan, rate: 8_000,
            evaluator: PreparedValidationTestEvaluator(startingState: state,
                control: PreparedValidationControl(), mode: .actualSuccessor)).preparedPhrase)
        #expect(sameSource.commitEligible)
        #expect(seal.admittedUpdate(for: sameSource, incomingState: state,
            incomingAdaptation: wrongState, policy: policy) == nil)
        #expect(seal.admittedUpdate(for: sameSource, incomingState: director.initialState(),
            incomingAdaptation: incoming, policy: policy) == nil)
        let otherArtifacts = try qualifiedArtifacts()
        let otherPolicy = try LongHorizonProfessionalPolicy(profile: otherArtifacts.profile,
            adversarial: otherArtifacts.adversarial, holdout: otherArtifacts.holdout)
        #expect(seal.admittedUpdate(for: sameSource, incomingState: state,
            incomingAdaptation: incoming, policy: otherPolicy) == nil)
        let wrongControl = PreparedValidationControl()
        let wrong = try #require(prepareValidationSource(state: state, plan: plan, rate: 8_000,
            evaluator: PreparedValidationTestEvaluator(startingState: state, control: wrongControl,
                mode: .actualSuccessor, longHorizonState: wrongState, longHorizonPolicy: policy)).preparedPhrase)
        #expect(!wrong.commitEligible && wrongControl.snapshot.projection == nil)
        #expect(wrongControl.snapshot.probes == 0)
        print(String(decoding: try JSONSerialization.data(withJSONObject:
            ["fixture": "private-long-horizon-projection.v1", "rows": rows,
             "unadmittedAndForeignSourcesRefused": true, "wrongIncomingStateRefused": true,
             "incomingStateUnchanged": true, "foreignSessionAdaptationAndPolicyRefused": true,
             "qualification": "mechanical-only-not-installed"],
            options: [.sortedKeys]), as: UTF8.self))
    }

    private func prepareValidationSource(state: AutonomousSessionState,
        plan: AutonomousPhrasePlan, rate: Double,
        evaluator: PreparedValidationTestEvaluator,
        routeGeneration: Int = 0) -> AutonomousPhrasePreparationOutcome {
        AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
            plan: plan, sessionSeed: state.rootSeed, memory: state.memory, sampleRate: rate,
            incomingRenderState: Self.incomingControlState(startBar: plan.startBar),
            incomingGraphState: GeneratedDSPContinuationState(), previousGraph: nil,
            incomingQualityState: state.quality, routeGeneration: routeGeneration,
            evaluator: evaluator, cancellationRequested: { evaluator.control.snapshot.cancelled })
    }

    private final class PreparedValidationControl: @unchecked Sendable {
        struct Snapshot {
            var calls = 0; var probes = 0; var assessments = 0
            var probeWasCommitEligible = false; var cancelled = false
            var projection: LongHorizonProspectiveAdaptation?
            var signal: LongHorizonSignalPhraseEvidence?
        }
        private let lock = NSLock()
        private var state = Snapshot()
        let cached: AutonomousCandidatePreparedValidation?
        init(cached: AutonomousCandidatePreparedValidation? = nil) { self.cached = cached }
        var snapshot: Snapshot { lock.lock(); defer { lock.unlock() }; return state }
        func update(_ change: (inout Snapshot) -> Void) {
            lock.lock(); defer { lock.unlock() }; change(&state)
        }
    }

    private struct PreparedValidationTestEvaluator: AutonomousCandidateEvaluating {
        enum Mode: Equatable { case actualSuccessor, missingProof, missingSuccessor, unacceptedSuccessor, reject,
            changedAcceptedReason, foreignProof, cancel }
        let startingState: AutonomousSessionState
        let control: PreparedValidationControl
        let mode: Mode
        var correct = false
        var longHorizonState: LongHorizonFutureAdaptationState? = nil
        var longHorizonPolicy: LongHorizonProfessionalPolicy? = nil
        let policyVersion = "test-primary-calibrated.v1"
        let evaluatorVersion = "test-prepared-validation.v1"
        var requiresPreparedValidation: Bool { true }
        func requestsHomeUpperTimbreCorrection(for candidate: AutonomousCandidateEvaluationVector) -> Bool { correct }
        func terminalVerdict(selected: AutonomousCandidateEvaluationVector,
            transaction: AutonomousCandidateEvaluationTransaction) -> AutonomousCandidatePolicyVerdict {
            Self.accepted(transaction)
        }
        static func accepted(_ transaction: AutonomousCandidateEvaluationTransaction,
            extraReason: Bool = false) -> AutonomousCandidatePolicyVerdict {
            AutonomousCandidatePolicyVerdict(outcome: transaction.correctionCount == 0 ? .qualified : .adjusted,
                decisionBasis: .calibratedQuality,
                reasonCodes: [transaction.correctionCount == 0 ? .candidateQualifiedV1 : .candidateAdjustedV1] +
                    (extraReason ? [.routeRecoveryV1] : []))
        }
        func preparedValidation(for preview: AutonomousCandidatePreparedPreview) -> AutonomousCandidatePreparedValidation? {
            control.update { $0.calls += 1 }
            if mode == .missingProof { return nil }
            if mode == .foreignProof { return control.cached }
            if mode == .cancel { control.update { $0.cancelled = true }; return nil }
            var projection: LongHorizonProspectiveAdaptation?
            if let longHorizonState, let longHorizonPolicy {
                projection = longHorizonState.projecting(preview: preview,
                    incomingState: startingState, policy: longHorizonPolicy)
                control.update {
                    $0.projection = projection
                    $0.signal = LongHorizonSignalPhraseEvidence.make(preview: preview)
                }
                guard projection != nil else { return nil }
            }
            var successor: PreparedAutonomousPhrase?
            if mode != .missingSuccessor {
                let next = startingState.advance(using: preview.plan, quality: preview.prospectiveQualityState,
                    liveMasterHeadroom: preview.prospectiveLiveMasterState,
                    longHorizonDecision: projection?.decision)
                let director = AutonomousSessionDirector(rootSeed: next.rootSeed)
                control.update { $0.probes += 1 }
                successor = AutonomousPhrasePreparer.prepareIfNotCancelled(
                    plan: director.plan(from: next), sessionSeed: next.rootSeed, memory: next.memory,
                    sampleRate: preview.selectedCandidateEvidence.routeContinuation.sampleRate,
                    incomingRenderState: preview.endingRenderState, incomingGraphState: preview.endingGraphState,
                    previousGraph: preview.graph, incomingQualityState: next.quality,
                    routeGeneration: preview.selectedCandidateEvidence.routeContinuation.routeGeneration,
                    evaluator: ValidationProbeTestEvaluator(policyVersion: policyVersion, evaluatorVersion: evaluatorVersion,
                        allowAcceptance: mode != .unacceptedSuccessor),
                    cancellationRequested: { false })
                control.update { $0.probeWasCommitEligible = successor?.commitEligible ?? false }
                if successor == nil { return nil }
            }
            return try? preview.assessingContinuous(successor: successor) { _ in
                control.update { $0.assessments += 1 }
                return mode == .reject ? AutonomousCandidatePolicyVerdict(outcome: .rejected,
                    decisionBasis: .calibratedQuality, reasonCodes: [.guardrailRegressionV1]) :
                    Self.accepted(preview.transaction, extraReason: mode == .changedAcceptedReason)
            }
        }
    }

    private struct ValidationProbeTestEvaluator: AutonomousCandidateEvaluating {
        let policyVersion: String; let evaluatorVersion: String
        let allowAcceptance: Bool
        var requiresPreparedValidation: Bool { true }
        func requestsHomeUpperTimbreCorrection(for candidate: AutonomousCandidateEvaluationVector) -> Bool { false }
        func terminalVerdict(selected: AutonomousCandidateEvaluationVector,
            transaction: AutonomousCandidateEvaluationTransaction) -> AutonomousCandidatePolicyVerdict {
            allowAcceptance ? PreparedValidationTestEvaluator.accepted(transaction) :
                AutonomousCandidatePolicyVerdict(outcome: .qualificationUnavailable, decisionBasis: .unavailable,
                    reasonCodes: [.evaluatorUnavailableV1])
        }
        func preparedValidation(for preview: AutonomousCandidatePreparedPreview) -> AutonomousCandidatePreparedValidation? {
            // The bounded mechanical successor can accept only its own complete
            // source-local windows. It never recursively manufactures a suffix.
            try? preview.assessingContinuous { _ in
                PreparedValidationTestEvaluator.accepted(preview.transaction)
            }
        }
    }

    @Test("Continuous calibration keeps real bank membership and refuses unsupported fitting")
    func continuousCalibrationMembershipAndFitting() throws {
        // Public mechanical construction control, not a fresh calibration
        // population or quality label. The fixed phrase21 suffix is the same
        // preregistered score-only geometry used by actualSuccessorReportJoin.
        let fixture = try continuousBankControl()
        let bank = fixture.bank
        let receipts = fixture.receipts
        let legacy = try ProfessionalQualityCalibrationTrajectory(bank: bank)
        let incomplete = try ProfessionalQualityCalibrationTrajectory(continuousBank: bank)
        let complete = try ProfessionalQualityCalibrationTrajectory(continuousBank: bank, successors: receipts)
        #expect(complete.isComplete && incomplete.isComplete)
        #expect(complete.sourceBankFingerprint == legacy.sourceBankFingerprint)
        #expect(incomplete.sourceBankFingerprint == complete.sourceBankFingerprint)
        #expect(complete.observations.count == 14)
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationTrajectory(sourceBankFingerprint: "manufactured-membership",
                observations: complete.observations)
        }
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationCorpus(trajectories: [complete, incomplete])
        }
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationCorpus(trajectories: [complete, legacy])
        }
        let distinctLegacy = try ProfessionalQualityCalibrationTrajectory(
            sourceBankFingerprint: "reduced-legacy-algebra-fixture", observations: legacy.observations)
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationCorpus(trajectories: [complete, distinctLegacy])
        }
        let oneRateBank = try ProfessionalEvidenceReportBank(reports:
            bank.reports.filter { $0.sampleRate == 44_100 })
        #expect(throws: ProfessionalQualityCalibrationError.incompleteRepresentativeRates) {
            try ProfessionalQualityCalibrationTrajectory(continuousBank: oneRateBank)
        }
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationCorpus(continuousBanks: [bank], successorsByBank: [])
        }
        let corpus = try ProfessionalQualityCalibrationCorpus(continuousBanks: [bank], successorsByBank: [receipts])
        #expect(corpus.isComplete && corpus.sourceTrajectoryCount == 1)
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationProfile(corpus: corpus)
        }
        let corpusData = try corpus.deterministicJSON()
        let rebuilt = try ProfessionalQualityCalibrationCorpus.decodeValidated(corpusData,
            banks: [bank], successorsByBank: [receipts])
        #expect(rebuilt == corpus)
        #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
            try ProfessionalQualityCalibrationCorpus.decodeValidated(corpusData,
                banks: [bank], successorsByBank: [[]])
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ProfessionalQualityCalibrationCorpus.self, from: corpusData)
        }
        let unavailable = ProfessionalQualityMeasurementContract.unavailableMeasurements(in: incomplete.observations)
        #expect(!unavailable.isEmpty)
        #expect(throws: ProfessionalQualityCalibrationError.unavailableMeasurement(unavailable[0])) {
            try ProfessionalQualityCalibrationProfile(continuousBank: bank)
        }
        let unsupportedTrainingMetrics = ProfessionalQualityMetric.allCases.filter { metric in
            !complete.observations.contains { $0.measurementIsApplicable(metric) }
        }
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: [
            "fixture": "continuous-reduced-corpus-training-support.v1",
            "sourceBankFingerprint": complete.sourceBankFingerprint,
            "unsupportedTrainingMetrics": unsupportedTrainingMetrics.map(\.rawValue),
            "qualification": "diagnostic-not-activated"
        ], options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
        #expect(complete.sourceBankFingerprint == "11743474e0cedea5")
        #expect(unsupportedTrainingMetrics == [.upperPercussionTailRenderedTailToAttackDBMean])
        #expect(throws: ProfessionalQualityCalibrationError.invalidMetricSet) {
            try ProfessionalQualityCalibrationProfile(continuousBank: bank, successors: receipts)
        }
        let supported = try ProfessionalQualityCalibrationTrajectory(
            continuousBank: fixture.supportedBank, successors: fixture.supportedReceipts)
        #expect(supported.sourceBankFingerprint != complete.sourceBankFingerprint)
        #expect(supported.observations.contains {
            $0.measurementIsApplicable(.upperPercussionTailRenderedTailToAttackDBMean)
        })
        let profile = try ProfessionalQualityCalibrationProfile(
            continuousBank: fixture.supportedBank, successors: fixture.supportedReceipts)
        #expect(profile.isComplete && !profile.usesDiverseCalibration)
        #expect(profile.measurementScope == .continuousModalWindow)
        #expect(profile.schemaVersion == 24 && profile.profileVersion ==
            ProfessionalQualityMeasurementContract.continuousModalProfileVersion)
        #expect(profile.sourceTrajectoryCount == 1)
        let profileRebuilt = try ProfessionalQualityCalibrationProfile.decodeDeterministicJSON(profile.deterministicJSON())
        #expect(profileRebuilt == profile)

        // The fixed foreign-rate challenge must corrupt only the outer rate,
        // never erase actual source/support ownership or change scope to legacy.
        func rateOnlyChanged(_ original: ProfessionalQualityObservation,
                             _ challenged: ProfessionalQualityObservation) throws {
            var originalFields = try #require(JSONSerialization.jsonObject(
                with: original.deterministicJSON()) as? [String: Any])
            var challengedFields = try #require(JSONSerialization.jsonObject(
                with: challenged.deterministicJSON()) as? [String: Any])
            let claimedRate = try #require(challengedFields.removeValue(
                forKey: "sampleRate") as? NSNumber)
            originalFields.removeValue(forKey: "sampleRate")
            let retainedFields = NSDictionary(dictionary: originalFields)
                .isEqual(to: challengedFields)
            #expect(claimedRate.doubleValue == 96_000)
            #expect(retainedFields)
        }
        for source in bank.reports {
            let sourceIdentity = ProfessionalQualityModalSuccessorEvidence.identity(source)
            let receipt = try #require(receipts.first {
                $0.sourceIdentityFingerprint == sourceIdentity
            })
            let original = try ProfessionalQualityObservation(continuousReport: source,
                successor: receipt)
            let challenged = original.foreignRateChallenge()
            try rateOnlyChanged(original, challenged)
            #expect(original.isComplete && !challenged.isComplete)
            #expect(challenged.measurementScope == .continuousModalWindow)
            #expect(challenged.continuousModalSource == original.continuousModalSource)
            #expect(challenged.continuousModalSource?.projection.sampleRate == source.sampleRate)
            // Match every identity prerequisite before the existing rate guard.
            #expect(profile.isComplete)
            #expect(challenged.evidenceVersion == profile.evidenceVersion)
            #expect(challenged.observationVersion == profile.observationVersion)
            #expect(profile[challenged.checkpoint] != nil)
            #expect(!profile.sampleRates.contains(challenged.sampleRate))
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(challenged, against: profile)
            #expect(!verdict.accepted && verdict.reasons == [.profileMismatch])
            #expect(verdict.failedMetrics.isEmpty)
            #expect(throws: ProfessionalEvidenceReportBankError.inconsistentIdentity) {
                try ProfessionalQualityObservation.decodeValidated(challenged.deterministicJSON(),
                    report: source, successor: receipt)
            }
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(ProfessionalQualityObservation.self,
                    from: challenged.deterministicJSON())
            }
            let barLocal = try ProfessionalQualityObservation(report: source,
                requiringModalWindowSupport: true)
            let barLocalChallenge = barLocal.foreignRateChallenge()
            try rateOnlyChanged(barLocal, barLocalChallenge)
            #expect(!barLocalChallenge.isComplete)
            #expect(barLocalChallenge.measurementScope == .barLocalModalWindow)
            #expect(throws: ProfessionalQualityCalibrationError.invalidMetricSet) {
                try ProfessionalQualityObservation(engineVersion: barLocal.engineVersion,
                    evidenceVersion: barLocal.evidenceVersion, checkpoint: barLocal.checkpoint,
                    sampleRate: 96_000, hardGatesPassed: barLocal.hardGatesPassed,
                    liveMaster: barLocal.liveMaster, metrics: barLocal.metrics,
                    modalWindowSupport: barLocal.modalWindowSupport)
            }
            let legacyObservation = try ProfessionalQualityObservation(report: source)
            let legacyChallenge = legacyObservation.foreignRateChallenge()
            try rateOnlyChanged(legacyObservation, legacyChallenge)
            let historicalChallenge = try ProfessionalQualityObservation(
                engineVersion: legacyObservation.engineVersion,
                evidenceVersion: legacyObservation.evidenceVersion,
                checkpoint: legacyObservation.checkpoint, sampleRate: 96_000,
                hardGatesPassed: legacyObservation.hardGatesPassed,
                liveMaster: legacyObservation.liveMaster, metrics: legacyObservation.metrics,
                upperPercussionTailSupport: legacyObservation.upperPercussionTailSupport)
            #expect(try legacyChallenge.deterministicJSON() == historicalChallenge.deterministicJSON())
        }
        let invalidSources = complete.observations.map { $0.foreignRateChallenge() }
        #expect(throws: ProfessionalQualityCalibrationError.invalidIdentity) {
            try ProfessionalQualityCalibrationProfile(engineVersion: profile.engineVersion,
                evidenceVersion: profile.evidenceVersion,
                sourceBankFingerprint: complete.sourceBankFingerprint,
                sampleRates: profile.sampleRates, observations: invalidSources)
        }
        for observation in incomplete.observations where
            observation.measurementApplicability(.modalPercussionTailToBodyDBMean) == .unavailable {
            let challenged = try observation.replacing(.maximumBoundaryDelta, with: 100)
            let verdict = ProfessionalQualityProfileEvaluator.evaluate(challenged, against: profile)
            #expect(verdict.reasons.contains(.unavailableMeasurement))
            #expect(verdict.failedMetrics.contains(.modalPercussionTailToBodyDBMean))
            #expect(verdict.failedMetrics.contains(.maximumBoundaryDelta))
        }
        // Activation belongs to the existing readiness/artifact controls. A
        // complete one-bank construction profile remains insufficient and is
        // within the primary scope but below its required diverse support.
        #expect(profile.profileVersion == ProfessionalQualityPrimaryEvaluator.requiredProfileVersion)
        #expect(!profile.usesDiverseCalibration)
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: [
            "fixture": "continuous-modal-observation-foundation.v2",
            "unsupportedOriginalTrainingMetrics": unsupportedTrainingMetrics.map(\.rawValue),
            "supportedSourceBankFingerprint": supported.sourceBankFingerprint,
            "sourceBankFingerprint": complete.sourceBankFingerprint,
            "observationVersion": profile.observationVersion, "profileVersion": profile.profileVersion,
            "observationCount": complete.observations.count, "sourceTrajectoryCount": profile.sourceTrajectoryCount,
            "requiredUnavailableWithoutSuccessor": unavailable.count,
            "qualification": "unavailable-not-activated"
        ], options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @inline(never)
    private static func neutralControlState() -> RenderState { RenderState() }

    @inline(never)
    private static func bindControlState(_ state: inout RenderState, startBar: Int) {
        state.barIndex = startBar
    }

    @inline(never)
    private static func incomingControlState(startBar: Int) -> RenderState {
        var state = neutralControlState()
        bindControlState(&state, startBar: startBar)
        return state
    }

    private func continuousBankControl() throws ->
        (bank: ProfessionalEvidenceReportBank, receipts: [ProfessionalQualityModalSuccessorEvidence],
         supportedBank: ProfessionalEvidenceReportBank,
         supportedReceipts: [ProfessionalQualityModalSuccessorEvidence]) {
        let director = AutonomousSessionDirector(rootSeed: 48_300)
        var reports: [CanonicalJourneyQualificationReport] = []
        var receipts: [ProfessionalQualityModalSuccessorEvidence] = []
        var supportReports: [CanonicalJourneyQualificationReport] = []
        var supportReceipts: [ProfessionalQualityModalSuccessorEvidence] = []
        // Declare one positive score population before any PCM. Preserve the
        // original bank as the missing-population negative control. This is a
        // mechanical construction fixture, separate from the frozen 40/6 study.
        var planningState = director.initialState()
        var supportSelection: (checkpoint: CanonicalJourneyCheckpoint, phraseIndex: Int)?
        for _ in 0..<128 {
            let plan = director.plan(from: planningState)
            let labels = CanonicalJourneyCheckpoint.applicable(
                phraseIndex: plan.phraseIndex, phraseKind: plan.kind,
                chapterChanged: false)
            if let checkpoint = labels.first,
               plan.resolvedBars.contains(where: { bar in
                   bar.upperPercussionTailArticulations.contains { $0.role == .foregroundClearance }
               }) {
                supportSelection = (checkpoint, plan.phraseIndex)
                break
            }
            planningState.advancePlanning(using: plan)
        }
        let supportedSelection = try #require(supportSelection)
        let checkpoints = CanonicalJourneyQualificationHarness(engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: "continuous-modal-mechanical-control", routeGeneration: 0)
            .planCheckpoints(director: director)
        for rate in ProfessionalQualityCalibrationProfile.requiredSampleRates {
            var state = director.initialState()
            for _ in 0..<128 {
                let plan = director.plan(from: state)
                let selected = checkpoints.filter { checkpoint in
                    checkpoint.checkpoint == .longContinuation
                        ? plan.phraseIndex == 21 : checkpoint.phraseIndex == plan.phraseIndex
                }.map(\.checkpoint)
                let isSupportSource = plan.phraseIndex == supportedSelection.phraseIndex
                if !selected.isEmpty || isSupportSource {
                    let input = Self.incomingControlState(startBar: plan.startBar)
                    let originResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
                        plan: plan, sessionSeed: state.rootSeed, memory: state.memory, sampleRate: rate,
                        incomingRenderState: input, incomingGraphState: GeneratedDSPContinuationState(),
                        previousGraph: nil, incomingQualityState: state.quality,
                        evaluator: ProfessionalEvidenceOnlyEvaluator(), cancellationRequested: { false })
                    let origin = try #require(originResult)
                    let nextState = state.advance(using: origin.plan, quality: origin.qualityContinuationState,
                        liveMasterHeadroom: origin.liveMasterHeadroomContinuationState)
                    let nextPlan = director.plan(from: nextState)
                    let nextResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
                        plan: nextPlan, sessionSeed: nextState.rootSeed, memory: nextState.memory, sampleRate: rate,
                        incomingRenderState: origin.endingRenderState, incomingGraphState: origin.endingGraphState,
                        previousGraph: origin.graph, incomingQualityState: nextState.quality,
                        evaluator: ProfessionalEvidenceOnlyEvaluator(), cancellationRequested: { false })
                    let next = try #require(nextResult)
                    for checkpoint in selected {
                        let source = try report(origin, label: "continuous-modal-construction-control", checkpoint: checkpoint)
                        reports.append(source)
                        receipts.append(try .init(source: source, successor: next))
                    }
                    if isSupportSource {
                        let source = try report(origin, label: "continuous-modal-construction-control",
                            checkpoint: supportedSelection.checkpoint)
                        supportReports.append(source)
                        supportReceipts.append(try .init(source: source, successor: next))
                    }
                }
                if reports.filter({ $0.sampleRate == rate }).count == CanonicalJourneyCheckpoint.allCases.count &&
                    supportReports.contains(where: { $0.sampleRate == rate }) { break }
                state.advancePlanning(using: plan)
            }
        }
        let retained = reports.filter { $0.checkpoint != supportedSelection.checkpoint }
        let retainedIdentities = Set(retained.map(ProfessionalQualityModalSuccessorEvidence.identity))
        let retainedReceipts = receipts.filter { retainedIdentities.contains($0.sourceIdentityFingerprint) }
        return (try ProfessionalEvidenceReportBank(reports: reports), receipts,
            try ProfessionalEvidenceReportBank(reports: retained + supportReports), retainedReceipts + supportReceipts)
    }

    private func report(_ prepared: PreparedAutonomousPhrase, label: String,
                        checkpoint: CanonicalJourneyCheckpoint? = nil) throws -> CanonicalJourneyQualificationReport {
        let vector = prepared.selectedCandidateEvidence
        let applicable = CanonicalJourneyCheckpoint.applicable(phraseIndex: vector.symbolic.phraseIndex,
            phraseKind: prepared.plan.kind, chapterChanged: vector.symbolic.chapterChanged)
        let selected = try #require(checkpoint ?? applicable.first)
        let harness = CanonicalJourneyQualificationHarness(engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: vector.routeContinuation.routeFingerprint, routeGeneration: vector.routeContinuation.routeGeneration)
        return try harness.report(checkpoint: selected, prepared: prepared,
            fixtureFingerprint: label, continuationFingerprint: vector.routeContinuation.incomingContinuationFingerprint)
    }

    private func bankIncluding(_ source: CanonicalJourneyQualificationReport,
                               director: AutonomousSessionDirector) throws -> ProfessionalEvidenceReportBank {
        var reports = [source]
        let harness = CanonicalJourneyQualificationHarness(engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: source.routeFingerprint, routeGeneration: source.routeGeneration)
        let checkpoints = harness.planCheckpoints(director: director)
        var state = director.initialState()
        for _ in 0..<128 {
            let plan = director.plan(from: state)
            let applicable = checkpoints.filter { $0.phraseIndex == plan.phraseIndex }
                .map(\.checkpoint).filter { checkpoint in !reports.contains { $0.checkpoint == checkpoint } }
            if !applicable.isEmpty {
                var input = RenderState(); input.barIndex = plan.startBar
                let preparedResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
                    plan: plan, sessionSeed: state.rootSeed, memory: state.memory, sampleRate: 8_000,
                    incomingRenderState: input, incomingGraphState: GeneratedDSPContinuationState(), previousGraph: nil,
                    incomingQualityState: state.quality, evaluator: ProfessionalEvidenceOnlyEvaluator(), cancellationRequested: { false })
                let prepared = try #require(preparedResult)
                for checkpoint in applicable { reports.append(try report(prepared, label: "bank-ownership", checkpoint: checkpoint)) }
            }
            if reports.count == CanonicalJourneyCheckpoint.allCases.count { break }
            state.advancePlanning(using: plan)
        }
        return try ProfessionalEvidenceReportBank(reports: reports)
    }
}
