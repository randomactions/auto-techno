import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Modal successor report join", .serialized)
struct ModalSuccessorReportJoinTests {
    @Test("Frozen public score selection joins only the actual successor at all fixed rates")
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
            #expect(before.tailBodySupport.partialWindowEventCount + before.tailBodySupport.missingWindowEventCount == pending)
            #expect(joined.tailBodySupport.partialWindowEventCount + joined.tailBodySupport.missingWindowEventCount == 0)
            #expect(source.decision.outcome == .qualificationUnavailable && next.qualityDecision.outcome == .qualificationUnavailable)
            let data = try receipt.deterministicJSON()
            #expect(try ProfessionalQualityModalSuccessorEvidence.decodeValidated(data,
                source: source, successor: next) == receipt)
            let renamed = try report(origin, label: "retargeted-source")
            #expect(renamed.evidenceFingerprint == source.evidenceFingerprint)
            #expect(ProfessionalQualityModalSuccessorEvidence.identity(renamed) != receipt.sourceIdentityFingerprint)
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
