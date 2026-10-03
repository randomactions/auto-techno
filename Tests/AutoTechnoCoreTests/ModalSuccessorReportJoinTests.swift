import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Modal successor report join", .serialized)
struct ModalSuccessorReportJoinTests {
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

    @Test("Continuous qualification metadata cannot change installed legacy authority")
    func continuousQualificationScopeControls() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        let suite = artifacts.adversarialSuite
        let holdout = artifacts.holdoutQualification
        #expect(suite.measurementScope == .legacy && suite.sourceObservationVersion == nil)
        #expect(holdout.measurementScope == .legacy && holdout.sourceObservationVersion == nil)
        #expect(suite.fingerprint == ProfessionalQualityPrimaryArtifacts.expectedAdversarialSuiteFingerprint)
        #expect(holdout.fingerprint == ProfessionalQualityPrimaryArtifacts.expectedHoldoutQualificationFingerprint)
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

        // A coherent diagnostic envelope still cannot bind to the installed
        // legacy profile or authorize the primary runtime evaluator.
        let continuousSuiteData = try changed(suite.deterministicJSON(), values: [
            "sourceObservationVersion": continuousVersion, "schemaVersion": 23,
            "suiteVersion": "autotechno-professional-quality-adversarial.v24"])
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

    @Test("Continuous holdout diagnostics cannot enter the installed primary evaluator")
    func continuousHoldoutPrimaryScopeRejection() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        var object = try #require(JSONSerialization.jsonObject(
            with: artifacts.holdoutQualification.deterministicJSON()) as? [String: Any])
        object["schemaVersion"] = 21
        object["qualificationVersion"] = "autotechno-professional-quality-holdout.v21"
        object["evaluatorVersion"] = "autotechno-professional-quality-holdout-evaluator.v21"
        object["sourceObservationVersion"] = ProfessionalQualityMeasurementScope.continuousModalWindow.observationVersion
        let data = try JSONSerialization.data(withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes])
        let diagnostic = try ProfessionalQualityHoldoutQualification.decodeDeterministicJSON(data)
        #expect(diagnostic.measurementScope == .continuousModalWindow && diagnostic.qualified)
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
                "receiptFingerprint": receipt.fingerprint, "qualification": "unavailable-not-activated"])
        }
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:
            ["fixture": "modal-successor-report-join.v1", "publicSeed": initial.rootSeed,
             "phraseIndex": plan.phraseIndex, "startBar": plan.startBar, "rows": rows], options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
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
        let profile = try ProfessionalQualityCalibrationProfile(continuousBank: bank, successors: receipts)
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
                liveMaster: legacyObservation.liveMaster, metrics: legacyObservation.metrics)
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
        let installed = try ProfessionalQualityPrimaryArtifacts.load()
        #expect(installed.profile.profileVersion == ProfessionalQualityCalibrationProfile.profileVersion)
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: [
            "fixture": "continuous-modal-observation-foundation.v1",
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
        (bank: ProfessionalEvidenceReportBank, receipts: [ProfessionalQualityModalSuccessorEvidence]) {
        let director = AutonomousSessionDirector(rootSeed: 48_300)
        var reports: [CanonicalJourneyQualificationReport] = []
        var receipts: [ProfessionalQualityModalSuccessorEvidence] = []
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
                if !selected.isEmpty {
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
                }
                if reports.filter({ $0.sampleRate == rate }).count == CanonicalJourneyCheckpoint.allCases.count { break }
                state.advancePlanning(using: plan)
            }
        }
        return (try ProfessionalEvidenceReportBank(reports: reports), receipts)
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
