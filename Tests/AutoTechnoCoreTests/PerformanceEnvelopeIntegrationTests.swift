#if canImport(CryptoKit) && canImport(Darwin)
import AutoTechnoCore
@testable import AutoTechnoDSP
@testable import AutoTechnoTransport
import CAutoTechnoRealtime
import CryptoKit
import Darwin
import Dispatch
import Foundation
import Testing

@Suite("Local performance envelope", .serialized)
struct PerformanceEnvelopeIntegrationTests {
    private static let warmupCount = 1
    private static let timedTrialCount = 3
    private static let producerWarmupBatchCount = 2
    private static let producerTimedTrialCount = 9
    private static let producerOperationsPerBatch = 128
    private static let producerFrameCounts = [128, 256, 512, 1_024]
    private static let measurementCaseId = "ATBC-V1-002-CONTRAST"

    private struct Corpus: Decodable {
        struct Policy: Decodable { let maximumPhrases: Int }
        struct Route: Decodable {
            let id: String
            let sampleRate: Int
            let channelCount: Int
            let routeGeneration: Int
            let routeRecovery: Bool
        }
        struct Case: Decodable {
            let id: String
            let rootSeed: UInt64
            let checkpoint: CanonicalJourneyCheckpoint
            let continuationClass: String
        }
        let schema: String
        let corpusVersion: Int
        let checkpointPolicy: Policy
        let routes: [Route]
        let cases: [Case]
    }

    private struct RawEnvelope: Encodable {
        let schema = "autotechno-performance-envelope-observations.v1"
        let observationVersion = 1
        let corpusSha256: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let buildConfiguration: String
        let clock: ClockIdentity
        let memory: MemoryIdentity
        let machine: MachineIdentity
        let trialPolicy: TrialPolicy
        let preparationObservations: [PreparationObservation]
        let producerObservations: [ProducerObservation]
    }

    private struct ClockIdentity: Encodable {
        let kind = "dispatch-uptime-monotonic"
        let unit = "nanoseconds"
        let samplingLocation = "detached-test-process"
    }

    private struct MemoryIdentity: Encodable {
        let kind = "getrusage-ru_maxrss"
        let unit = "bytes"
        let scope = "whole-test-process-high-water"
        let attribution = "monotonic-process-bound-not-phase-exclusive"
    }

    private struct MachineIdentity: Encodable {
        let operatingSystem: String
        let operatingSystemVersion: String
        let hardwareModel: String
        let processor: String
        let activeProcessorCount: Int
        let physicalMemoryBytes: UInt64
        let lowPowerModeEnabled: Bool
        let thermalState: String
    }

    private struct TrialPolicy: Encodable {
        let preparationWarmupCount: Int
        let preparationTimedTrialCount: Int
        let producerWarmupBatchCount: Int
        let producerTimedTrialCount: Int
        let producerOperationsPerBatch: Int
        let producerFrameCounts: [Int]
        let measurementCaseId: String
        let selectionRule = "largest-existing-baseline-frame-count"
        let ordering = "case-route-trial-ascending"
    }

    private struct PreparationObservation: Encodable {
        let id: String
        let caseId: String
        let routeId: String
        let rootSeed: UInt64
        let checkpoint: String
        let continuationClass: String
        let trialIndex: Int
        let phraseIndex: Int
        let startBar: Int
        let barCount: Int
        let frameCount: Int
        let sampleRate: Int
        let channelCount: Int
        let renderPassCount: Int
        let planningNanoseconds: UInt64
        let renderEvaluationNanoseconds: UInt64
        let longHorizonNanoseconds: UInt64
        let longHorizonUpdateAvailable: Bool
        let presentationNanoseconds: UInt64
        let completePreparationNanoseconds: UInt64
        let audioDurationNanoseconds: UInt64
        let calculatedPeakWorkingBytes: Int
        let calculatedMaximumPeakWorkingBytes: Int
        let processHighWaterBytesBefore: UInt64
        let processHighWaterBytesAfter: UInt64
        let planFingerprint: String
        let replayFingerprint: String
        let directSampleHash: String
        let completeSampleHash: String
        let directEvaluationFingerprint: String
        let completeEvaluationFingerprint: String
        let exactIdentityMatch: Bool
    }

    private struct ProducerObservation: Encodable {
        let id: String
        let frameCount: Int
        let trialIndex: Int
        let operationCount: Int
        let batchNanoseconds: UInt64
        let droppedPacketDelta: UInt64
        let rejectedPacketDelta: UInt64
        let exactRoundTrip: Bool
    }

    private struct TargetContext {
        let fixture: Corpus.Case
        let route: Corpus.Route
        let director: AutonomousSessionDirector
        let request: PhrasePreparationRequest
        let reference: PreparedPerformancePhrase
    }

    // This is a diagnostic of the normal shared owner using an explicit
    // retained model. It is neither installed-artifact qualification nor a
    // substitute for full journey, long-horizon, callback or output evidence.
    @MainActor
    @Test("Export frozen calibrated continuation-chain resource observations",
        .enabled(if: ProcessInfo.processInfo.environment["AUTOTECHNO_RUN_CONTINUOUS_PREPARATION_ENVELOPE"] == "1"))
    func exportContinuousPreparationEnvelope() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["AUTOTECHNO_PERFORMANCE_BUILD_CONFIGURATION"] == "release" else {
            throw EnvelopeError.releaseBuildRequired
        }
        let root = repositoryRoot
        let acceptedHead = try #require(environment["AUTOTECHNO_CONTINUOUS_ENVELOPE_ACCEPTED_HEAD"])
        let actualHead = try gitHead(root)
        guard acceptedHead == actualHead,
              try gitOutput(root, arguments: ["status", "--porcelain", "--untracked-files=all"]).isEmpty else {
            throw EnvelopeError.invalidObservation
        }
        let sourceBefore = try sourceFingerprint(root)
        let contractData = try Data(contentsOf: root.appendingPathComponent("docs/ROADMAP_EXECUTION_BASELINE.json"))
        let contract = try #require(JSONSerialization.jsonObject(with: contractData) as? [String: Any])
        let contractFingerprint = try #require(contract["snapshotFingerprint"] as? String)
        let retained = root.appendingPathComponent("docs/local/reports/rms-trajectory-floor/fresh-qualification-7ef30ff")
        let artifactNames = ["offline-profile.json", "continuous-adversarial-suite.json", "continuous-holdout-qualification.json"]
        let artifactData = try artifactNames.map { try Data(contentsOf: retained.appendingPathComponent($0)) }
        let artifacts = try ProfessionalQualityPrimaryArtifacts(profileData: artifactData[0],
            adversarialSuiteData: artifactData[1], holdoutQualificationData: artifactData[2])
        guard artifacts.profile.fingerprint == "4fb209bfb248d46b",
              artifacts.evaluator.requiresPreparedValidation else { throw EnvelopeError.invalidObservation }
        struct Entry: Decodable {
            struct Planning: Decodable { let rootSeed: UInt64 }
            let frozenPlanningEntry: Planning
        }
        let entryData = try Data(contentsOf: retained.appendingPathComponent("development-ordinal-777.json"))
        let entry = try JSONDecoder().decode(Entry.self, from: entryData)
        let output = root.appendingPathComponent("docs/local/reports/rms-trajectory-floor/continuous-preparation-envelope-" + acceptedHead.prefix(7))
        guard !FileManager.default.fileExists(atPath: output.path) else { throw EnvelopeError.invalidObservation }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var observations: [[String: Any]] = []
        let identity: [String: Any] = [
            "schema": "autotechno-continuous-preparation-envelope-observations.v1",
            "gitHead": acceptedHead, "sourceFingerprint": sourceBefore,
            "contractBaselineFingerprint": contractFingerprint,
            "buildConfiguration": "release", "engineVersion": QualityQualificationContract.engineVersion,
            "modelScope": "retained-7ef30ff-mechanical-only", "profileFingerprint": artifacts.profile.fingerprint,
            "artifactSha256": Dictionary(uniqueKeysWithValues: zip(artifactNames, artifactData.map(digest))),
            "initialFixtureSha256": digest(entryData),
            "clock": try JSONSerialization.jsonObject(with: JSONEncoder().encode(ClockIdentity())),
            "memory": try JSONSerialization.jsonObject(with: JSONEncoder().encode(MemoryIdentity())),
            "machine": try JSONSerialization.jsonObject(with: JSONEncoder().encode(machineIdentity())),
            "trialPolicy": ["warmupCount": Self.warmupCount, "timedTrialCount": Self.timedTrialCount,
                "sampleRates": [44_100, 48_000], "caseOrdering": ["development-ordinal-777-initial", "public-48300-planning-21"],
                "selectionRule": "existing-positive-initial-and-required-child-mechanical-controls",
                "warmupObservationsRetained": true],
            "maximumReservedNumericBytes": AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount,
            "runtimeActivation": false, "installedArtifactQualification": false,
            "fullJourneyQualification": false, "longHorizonQualification": false,
            "callbackOrPhysicalOutputQualification": false,
        ]
        func writeObservations(complete: Bool) throws {
            var document = identity
            document["executionComplete"] = complete
            document["observations"] = observations
            try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys, .prettyPrinted])
                .write(to: output.appendingPathComponent("raw-observations.json"), options: .atomic)
        }
        try writeObservations(complete: false)
        for caseId in ["development-ordinal-777-initial", "public-48300-planning-21"] {
            for rate in [44_100.0, 48_000.0] {
                let request: PhrasePreparationRequest
                if caseId == "public-48300-planning-21" {
                    // This fixture is a planning-only checkpoint with empty DSP
                    // history. Record refusal rather than claiming a full journey.
                    request = IterativeSuccessorPreparationTests.sourceRequest(rate: rate)
                } else {
                    let state = AutonomousSessionDirector(rootSeed: entry.frozenPlanningEntry.rootSeed).initialState()
                    let key = PhrasePreparationKey(sessionSeed: state.rootSeed, phraseIndex: state.phraseIndex,
                        sampleRate: rate, channelCount: 2, routeRecovery: false,
                        qualityRevision: state.quality.revision, qualityPolicyVersion: state.quality.policyVersion,
                        qualityControllerFingerprint: state.quality.observedControllerStateFingerprint ?? state.quality.acceptedControllerStateFingerprint,
                        routeGeneration: 0, incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
                        incomingLiveMasterStateFingerprint: state.liveMasterHeadroom.fingerprint,
                        pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil, liveTargetStartSample: nil)
                    request = PhrasePreparationRequest(key: key, sourceState: state, incomingLongHorizonState: nil,
                        incomingRenderState: RenderState(), incomingGraphState: GeneratedDSPContinuationState(),
                        previousGraph: nil, pendingLiveMasterBinding: nil)
                }
                for trial in -Self.warmupCount..<Self.timedTrialCount {
                    guard try gitHead(root) == acceptedHead,
                          try sourceFingerprint(root) == sourceBefore,
                          try gitOutput(root, arguments: ["status", "--porcelain", "--untracked-files=all"]).isEmpty else {
                        throw EnvelopeError.invalidObservation
                    }
                    let before = try processHighWaterBytes()
                    let measured = await Task.detached(priority: .userInitiated) {
                        let began = DispatchTime.now().uptimeNanoseconds
                        let outcome = AutonomousPerformancePreparer.prepareDiagnosing(request: request,
                            director: AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed),
                            artifacts: artifacts, longHorizonArtifacts: nil)
                        return (outcome, DispatchTime.now().uptimeNanoseconds - began)
                    }.value
                    let after = try processHighWaterBytes()
                    var row: [String: Any] = ["caseId": caseId, "sampleRate": rate, "channelCount": 2,
                        "trialIndex": trial, "isWarmup": trial < 0,
                        "sourcePhraseIndex": request.sourceState.phraseIndex,
                        "replayFingerprint": request.replayIdentity.fingerprint,
                        "completePreparationNanoseconds": measured.1,
                        "processHighWaterBytesBefore": before, "processHighWaterBytesAfter": after]
                    if let phrase = measured.0.preparedPhrase {
                        let nodes = [phrase] + phrase.retainedContinuations
                        let budget = phrase.preparationChainResourceBudget
                        let frames = phrase.prepared.audioPreflight.quality.analyzedFrameCount
                        let duration = UInt64(Double(frames) / rate * 1_000_000_000)
                        row["outcome"] = phrase.prepared.commitEligible ? "commit-eligible" : "calibrated-rejection"
                        row["requiresQualifiedSuccessor"] = phrase.requiresQualifiedContinuation
                        row["ownershipValid"] = phrase.continuationOwnershipIsValid
                        row["audioDurationNanoseconds"] = duration
                        row["preparationShorterThanRootDuration"] = measured.1 < duration
                        row["renderedProductsRetained"] = nodes.count
                        row["reservedPeakWorkingBytes"] = budget?.reservedPeakWorkingByteCount ?? NSNull() as Any
                        row["retainedNumericBytes"] = budget?.retainedNumericByteCount ?? NSNull() as Any
                        row["reservedSourceCount"] = budget?.sourceCount ?? NSNull() as Any
                        row["reservedMaximumRenderPassCount"] = budget?.maximumRenderPassCount ?? NSNull() as Any
                        row["qualityOutcome"] = String(describing: phrase.prepared.qualityDecision.outcome)
                        row["qualityReasonCodes"] = phrase.prepared.qualityDecision.reasonCodes.map { String(describing: $0) }
                        row["nodes"] = nodes.map { node -> [String: Any] in [
                            "phraseIndex": node.request.sourceState.phraseIndex,
                            "barCount": node.prepared.plan.barCount,
                            "frameCount": node.prepared.audioPreflight.quality.analyzedFrameCount,
                            "commitEligible": node.prepared.commitEligible,
                            "requiresQualifiedSuccessor": node.requiresQualifiedContinuation,
                            "sampleHash": node.prepared.audioPreflight.quality.sampleHash,
                            "replayFingerprint": node.request.replayIdentity.fingerprint,
                            "preparedOriginMatches": node.prepared.preparationReplayFingerprint == node.request.replayIdentity.fingerprint,
                        ] }
                        if phrase.prepared.commitEligible {
                            guard phrase.continuationOwnershipIsValid, let budget,
                                  budget.sourceCount == nodes.count,
                                  budget.reservedPeakWorkingByteCount <= AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount,
                                  !nodes.last!.requiresQualifiedContinuation else { throw EnvelopeError.invalidObservation }
                        }
                    } else {
                        let failure = try #require(measured.0.failure)
                        row["outcome"] = "preparation-refused"
                        row["failureStage"] = failure.stage
                        row["failureCode"] = failure.code
                        row["failureDetails"] = failure.details
                        // Refusal has no playable product or published budget;
                        // do not invent rendered counts, PCM or reserved peaks.
                    }
                    observations.append(row)
                    try writeObservations(complete: false)
                    print("continuous preparation envelope \(caseId) \(Int(rate)) trial \(trial): \(row["outcome"]!)")
                }
            }
        }
        guard try gitHead(root) == acceptedHead, try sourceFingerprint(root) == sourceBefore,
              try Data(contentsOf: root.appendingPathComponent("docs/ROADMAP_EXECUTION_BASELINE.json")) == contractData,
              try artifactNames.map({ try Data(contentsOf: retained.appendingPathComponent($0)) }) == artifactData,
              try Data(contentsOf: retained.appendingPathComponent("development-ordinal-777.json")) == entryData else {
            throw EnvelopeError.invalidObservation
        }
        try writeObservations(complete: true)
    }

    @MainActor
    @Test("Export current shared preparation with exact owned-child replay",
        .enabled(if: ProcessInfo.processInfo.environment["AUTOTECHNO_RUN_CURRENT_SHARED_PREPARATION_ENVELOPE"] == "1"))
    func exportCurrentSharedPreparationEnvelope() async throws {
        let environment = ProcessInfo.processInfo.environment
        #if DEBUG
        let optimizedBuild = false
        #else
        let optimizedBuild = true
        #endif
        guard optimizedBuild, environment["AUTOTECHNO_PERFORMANCE_BUILD_CONFIGURATION"] == "release" else {
            throw EnvelopeError.releaseBuildRequired
        }
        let root = repositoryRoot
        let acceptedHead = try #require(environment["AUTOTECHNO_CURRENT_SHARED_ENVELOPE_ACCEPTED_HEAD"])
        guard try gitHead(root) == acceptedHead,
            try gitOutput(root, arguments: ["status", "--porcelain", "--untracked-files=all"]).isEmpty
        else { throw EnvelopeError.invalidObservation }
        let sourceBefore = try sourceFingerprint(root)
        let contractData = try Data(contentsOf: root.appendingPathComponent("docs/ROADMAP_EXECUTION_BASELINE.json"))
        let contract = try #require(JSONSerialization.jsonObject(with: contractData) as? [String: Any])
        let corpusData = try Data(contentsOf: root.appendingPathComponent("docs/BASELINE_CORPUS.json"))
        let corpus = try JSONDecoder().decode(Corpus.self, from: corpusData)
        guard corpus.schema == "autotechno-baseline-corpus.v1", corpus.corpusVersion == 1,
            corpus.cases.count == 7, Set(corpus.cases.map(\.id)).count == 7,
            corpus.routes.map(\.sampleRate).sorted() == [44_100, 48_000],
            corpus.routes.allSatisfy({ $0.channelCount == 2 })
        else { throw EnvelopeError.unsupportedCorpus }
        let artifacts = try AutonomousPerformanceArtifactSet.load()
        let output = root.appendingPathComponent("docs/local/reports/current-shared-preparation-envelope-" + acceptedHead.prefix(7))
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw EnvelopeError.invalidObservation
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var observations: [[String: Any]] = []
        let identity: [String: Any] = [
            "schema": "autotechno-current-shared-preparation-envelope-observations.v1",
            "gitHead": acceptedHead, "sourceFingerprint": sourceBefore,
            "contractBaselineFingerprint": try #require(contract["snapshotFingerprint"] as? String),
            "corpusSha256": digest(corpusData), "engineVersion": QualityQualificationContract.engineVersion,
            "buildConfiguration": "release", "primaryPolicyVersion": artifacts.primary.evaluator.policyVersion,
            "longHorizonPolicyVersion": artifacts.longHorizon.policy.policyVersion,
            "clock": try JSONSerialization.jsonObject(with: JSONEncoder().encode(ClockIdentity())),
            "memory": try JSONSerialization.jsonObject(with: JSONEncoder().encode(MemoryIdentity())),
            "machine": try JSONSerialization.jsonObject(with: JSONEncoder().encode(machineIdentity())),
            "trialPolicy": ["warmupCount": Self.warmupCount, "timedTrialCount": Self.timedTrialCount,
                "caseIds": corpus.cases.map(\.id), "sampleRates": [44_100, 48_000],
                "ordering": "frozen-corpus-case-route-trial", "warmupObservationsRetained": true],
            "measurementScope": "all-baseline-checkpoints-through-current-shared-owner",
            "phaseTimingAvailability": "not-instrumented-shared-owner",
            "referenceStorageScope": "exact-journey-product-held-outside-timed-preparation",
            "maximumReservedNumericBytes": AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount,
            "capacityQualification": false, "runtimeActivation": false,
            "minMaxTwoPassRebuildQualification": false, "lifecycleQualification": false,
            "callbackOrPhysicalOutputQualification": false,
        ]
        func writeObservations(complete: Bool, producer: [ProducerObservation] = []) throws {
            var document = identity
            document["executionComplete"] = complete
            document["observations"] = observations
            document["producerObservations"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(producer))
            try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys, .prettyPrinted])
                .write(to: output.appendingPathComponent("raw-observations.json"), options: .atomic)
        }
        try writeObservations(complete: false)
        for fixture in corpus.cases {
            for route in corpus.routes {
                let context: TargetContext
                do {
                    context = try targetContext(fixture: fixture, route: route,
                        limit: corpus.checkpointPolicy.maximumPhrases,
                        primary: artifacts.primary, longHorizon: artifacts.longHorizon)
                } catch {
                    for trial in -Self.warmupCount..<Self.timedTrialCount {
                        var row: [String: Any] = ["caseId": fixture.id, "routeId": route.id,
                            "sampleRate": route.sampleRate, "channelCount": route.channelCount,
                            "trialIndex": trial, "isWarmup": trial < 0,
                            "outcome": "target-journey-unavailable"]
                        if let failure = error as? PhrasePreparationFailure {
                            row["failureStage"] = failure.stage; row["failureCode"] = failure.code
                            row["failureDetails"] = failure.details
                        } else { row["failureCode"] = String(describing: error) }
                        observations.append(row)
                    }
                    try writeObservations(complete: false)
                    continue
                }
                let reference = context.reference
                for trial in -Self.warmupCount..<Self.timedTrialCount {
                    guard try gitHead(root) == acceptedHead,
                        try sourceFingerprint(root) == sourceBefore,
                        try gitOutput(root, arguments: ["status", "--porcelain", "--untracked-files=all"]).isEmpty
                    else { throw EnvelopeError.invalidObservation }
                    let request = context.request
                    let before = try processHighWaterBytes()
                    let measured = await Task.detached(priority: .userInitiated) {
                        let began = DispatchTime.now().uptimeNanoseconds
                        let result = AutonomousPerformancePreparer.prepareDiagnosing(request: request,
                            director: AutonomousSessionDirector(rootSeed: request.sourceState.rootSeed),
                            artifacts: artifacts.primary, longHorizonArtifacts: artifacts.longHorizon)
                        return (result, DispatchTime.now().uptimeNanoseconds - began)
                    }.value
                    let after = try processHighWaterBytes()
                    guard after >= before else { throw EnvelopeError.invalidObservation }
                    var row: [String: Any] = ["caseId": fixture.id, "routeId": route.id,
                        "rootSeed": fixture.rootSeed, "checkpoint": fixture.checkpoint.rawValue,
                        "sampleRate": route.sampleRate, "channelCount": route.channelCount,
                        "trialIndex": trial, "isWarmup": trial < 0,
                        "sourcePhraseIndex": request.sourceState.phraseIndex,
                        "replayFingerprint": request.replayIdentity.fingerprint,
                        "completePreparationNanoseconds": measured.1,
                        "processHighWaterBytesBefore": before, "processHighWaterBytesAfter": after,
                        "referenceNodes": currentEnvelopeNodes(reference)]
                    if let product = measured.0.preparedPhrase {
                        let exact = currentEnvelopeProductsMatch(reference, product)
                        let frames = product.prepared.audioPreflight.quality.analyzedFrameCount
                        row["outcome"] = product.prepared.commitEligible ? "commit-eligible" : "calibrated-rejection"
                        row["exactJourneyIdentityMatch"] = exact
                        row["ownershipValid"] = product.continuationOwnershipIsValid
                        row["audioDurationNanoseconds"] = UInt64(Double(frames) / request.key.sampleRate * 1_000_000_000)
                        row["nodes"] = currentEnvelopeNodes(product)
                        row["qualityOutcome"] = String(describing: product.prepared.qualityDecision.outcome)
                        row["qualityReasonCodes"] = product.prepared.qualityDecision.reasonCodes.map { String(describing: $0) }
                        if let budget = product.preparationChainResourceBudget {
                            row["reservedPeakWorkingBytes"] = budget.reservedPeakWorkingByteCount
                            row["retainedNumericBytes"] = budget.retainedNumericByteCount
                            row["reservedSourceCount"] = budget.sourceCount
                            row["reservedMaximumRenderPassCount"] = budget.maximumRenderPassCount
                        }
                        if product.prepared.commitEligible {
                            guard exact, product.continuationOwnershipIsValid,
                                let budget = product.preparationChainResourceBudget,
                                budget.sourceCount == 1 + product.retainedContinuations.count,
                                budget.reservedPeakWorkingByteCount <= AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount
                            else {
                                row["outcome"] = "identity-or-resource-refused"
                                row["failureStage"] = "performance-envelope"
                                row["failureCode"] = "current-shared-identity-or-resource"
                                observations.append(row)
                                try writeObservations(complete: false)
                                throw EnvelopeError.invalidObservation
                            }
                        }
                    } else {
                        let failure = try #require(measured.0.failure)
                        row["outcome"] = "preparation-refused"
                        row["failureStage"] = failure.stage; row["failureCode"] = failure.code
                        row["failureDetails"] = failure.details
                    }
                    observations.append(row)
                    try writeObservations(complete: false)
                }
            }
        }
        guard try gitHead(root) == acceptedHead, try sourceFingerprint(root) == sourceBefore,
            try Data(contentsOf: root.appendingPathComponent("docs/ROADMAP_EXECUTION_BASELINE.json")) == contractData,
            try Data(contentsOf: root.appendingPathComponent("docs/BASELINE_CORPUS.json")) == corpusData
        else { throw EnvelopeError.invalidObservation }
        let producer = try producerBenchmark()
        try writeObservations(complete: true, producer: producer)
        #expect(observations.count == corpus.cases.count * corpus.routes.count * (Self.warmupCount + Self.timedTrialCount))
        #expect(observations.allSatisfy { $0["outcome"] as? String == "commit-eligible" })
        #expect(producer.count == 36 && producer.allSatisfy { $0.exactRoundTrip && $0.droppedPacketDelta == 0 && $0.rejectedPacketDelta == 0 })
    }

    private func currentEnvelopeNodes(_ product: PreparedPerformancePhrase) -> [[String: Any]] {
        ([product] + product.retainedContinuations).map { node in
            let advanced = node.request.sourceState.advance(using: node.prepared.plan,
                quality: node.prepared.qualityContinuationState,
                liveMasterHeadroom: node.prepared.liveMasterHeadroomContinuationState,
                longHorizonDecision: node.longHorizonDecision)
            return ["phraseIndex": node.prepared.plan.phraseIndex, "barCount": node.prepared.plan.barCount,
                "frameCount": node.prepared.audioPreflight.quality.analyzedFrameCount,
                "renderPassCount": node.prepared.correctionRenderCount + 1,
                "sampleHash": node.prepared.audioPreflight.quality.sampleHash,
                "planFingerprint": AutonomousCandidateFingerprint.plan(node.prepared.plan),
                "candidateEvaluationFingerprint": node.prepared.candidateEvaluationFingerprint,
                "replayFingerprint": node.request.replayIdentity.fingerprint,
                "incomingCoreFingerprint": AutonomousTypedFingerprint.sessionState(node.request.sourceState),
                "incomingRenderFingerprint": AutonomousTypedFingerprint.renderState(node.request.incomingRenderState),
                "incomingGraphFingerprint": AutonomousTypedFingerprint.generatedDSPState(node.request.incomingGraphState),
                "incomingLongHorizonFingerprint": node.request.incomingLongHorizonState?.fingerprint ?? "none",
                "preparedOriginMatches": node.prepared.preparationReplayFingerprint == node.request.replayIdentity.fingerprint,
                "outgoingCoreFingerprint": AutonomousTypedFingerprint.sessionState(advanced),
                "outgoingRenderFingerprint": AutonomousTypedFingerprint.renderState(node.prepared.endingRenderState),
                "outgoingGraphFingerprint": AutonomousTypedFingerprint.generatedDSPState(node.prepared.endingGraphState),
                "outgoingLongHorizonFingerprint": node.outgoingLongHorizonState?.fingerprint ?? "none",
                "commitEligible": node.prepared.commitEligible,
                "requiresQualifiedSuccessor": node.requiresQualifiedContinuation]
        }
    }

    private func currentEnvelopeProductsMatch(_ reference: PreparedPerformancePhrase,
        _ measured: PreparedPerformancePhrase) -> Bool {
        let expected = [reference] + reference.retainedContinuations
        let actual = [measured] + measured.retainedContinuations
        guard reference.continuationOwnershipIsValid, measured.continuationOwnershipIsValid,
            expected.count == actual.count else { return false }
        func advancedCoreFingerprint(_ node: PreparedPerformancePhrase) -> String {
            AutonomousTypedFingerprint.sessionState(node.request.sourceState.advance(
                using: node.prepared.plan, quality: node.prepared.qualityContinuationState,
                liveMasterHeadroom: node.prepared.liveMasterHeadroomContinuationState,
                longHorizonDecision: node.longHorizonDecision))
        }
        return zip(expected, actual).allSatisfy { pair in
            let (lhs, rhs) = pair
            return lhs.request.replayIdentity == rhs.request.replayIdentity &&
            advancedCoreFingerprint(lhs) == advancedCoreFingerprint(rhs) &&
            lhs.prepared.plan == rhs.prepared.plan && lhs.prepared.blocks == rhs.prepared.blocks &&
            lhs.prepared.repeatHoldEvolutions == rhs.prepared.repeatHoldEvolutions && lhs.waveforms == rhs.waveforms &&
            lhs.prepared.candidateEvaluationFingerprint == rhs.prepared.candidateEvaluationFingerprint &&
            lhs.prepared.preparationReplayFingerprint == rhs.prepared.preparationReplayFingerprint &&
            AutonomousTypedFingerprint.renderState(lhs.prepared.endingRenderState) == AutonomousTypedFingerprint.renderState(rhs.prepared.endingRenderState) &&
            AutonomousTypedFingerprint.generatedDSPState(lhs.prepared.endingGraphState) == AutonomousTypedFingerprint.generatedDSPState(rhs.prepared.endingGraphState) &&
            lhs.prepared.qualityContinuationState == rhs.prepared.qualityContinuationState &&
            lhs.prepared.liveMasterHeadroomContinuationState == rhs.prepared.liveMasterHeadroomContinuationState &&
            lhs.outgoingLongHorizonState?.fingerprint == rhs.outgoingLongHorizonState?.fingerprint
        }
    }

    @MainActor
    @Test("Export a release-only bounded performance envelope")
    func exportEnvelope() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["AUTOTECHNO_RUN_PERFORMANCE_ENVELOPE"] == "1" else {
            return
        }
        let buildConfiguration = environment[
            "AUTOTECHNO_PERFORMANCE_BUILD_CONFIGURATION"
        ] ?? ""
        guard buildConfiguration == "release" else {
            throw EnvelopeError.releaseBuildRequired
        }

        let root = repositoryRoot
        let corpusURL = root.appendingPathComponent("docs/BASELINE_CORPUS.json")
        let corpusData = try Data(contentsOf: corpusURL)
        let corpus = try JSONDecoder().decode(Corpus.self, from: corpusData)
        guard corpus.schema == "autotechno-baseline-corpus.v1",
              corpus.corpusVersion == 1,
              corpus.routes.map(\.sampleRate).sorted() == [44_100, 48_000],
              corpus.routes.allSatisfy({ $0.channelCount == 2 }),
              corpus.cases.count == 7 else {
            throw EnvelopeError.unsupportedCorpus
        }
        let baseline = try JSONSerialization.jsonObject(with: Data(
            contentsOf: root.appendingPathComponent(
                "docs/ROADMAP_EXECUTION_BASELINE.json"
            )
        )) as? [String: Any]
        let contractFingerprint = try #require(
            baseline?["snapshotFingerprint"] as? String
        )
        let primary = try ProfessionalQualityPrimaryArtifacts.load()
        guard !primary.evaluator.requiresPreparedValidation else {
            throw EnvelopeError.legacyIsolatedEnvelopeUnsupported
        }
        let longHorizon = try LongHorizonProfessionalPolicyArtifacts.load()

        var preparation: [PreparationObservation] = []
        let measurementCases = corpus.cases.filter {
            $0.id == Self.measurementCaseId
        }
        guard measurementCases.count == 1 else {
            throw EnvelopeError.unsupportedCorpus
        }
        preparation.reserveCapacity(
            measurementCases.count * corpus.routes.count * Self.timedTrialCount
        )
        for fixture in measurementCases {
            for route in corpus.routes {
                let context = try targetContext(
                    fixture: fixture,
                    route: route,
                    limit: corpus.checkpointPolicy.maximumPhrases,
                    primary: primary,
                    longHorizon: longHorizon
                )
                for _ in 0..<Self.warmupCount {
                    _ = try measure(
                        context: context,
                        trialIndex: -1,
                        primary: primary,
                        longHorizon: longHorizon
                    )
                }
                for trialIndex in 0..<Self.timedTrialCount {
                    preparation.append(try measure(
                        context: context,
                        trialIndex: trialIndex,
                        primary: primary,
                        longHorizon: longHorizon
                    ))
                }
                print(
                    "performance envelope measured \(fixture.id) " +
                    "\(route.id) (\(preparation.count)/6 trials)"
                )
            }
        }

        let producer = try producerBenchmark()
        let output = root.appendingPathComponent(
            "docs/local/reports/performance-envelope-v1",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: output,
            withIntermediateDirectories: true
        )
        let raw = RawEnvelope(
            corpusSha256: digest(corpusData),
            contractBaselineFingerprint: contractFingerprint,
            sourceFingerprint: try sourceFingerprint(root),
            gitHead: try gitHead(root),
            engineVersion: QualityQualificationContract.engineVersion,
            buildConfiguration: buildConfiguration,
            clock: ClockIdentity(),
            memory: MemoryIdentity(),
            machine: machineIdentity(),
            trialPolicy: TrialPolicy(
                preparationWarmupCount: Self.warmupCount,
                preparationTimedTrialCount: Self.timedTrialCount,
                producerWarmupBatchCount: Self.producerWarmupBatchCount,
                producerTimedTrialCount: Self.producerTimedTrialCount,
                producerOperationsPerBatch: Self.producerOperationsPerBatch,
                producerFrameCounts: Self.producerFrameCounts,
                measurementCaseId: Self.measurementCaseId
            ),
            preparationObservations: preparation,
            producerObservations: producer
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        try encoder.encode(raw).write(
            to: output.appendingPathComponent("raw-observations.json"),
            options: .atomic
        )

        let preparationIdentityIsExact = preparation.allSatisfy {
            $0.exactIdentityMatch
        }
        let producerRoundTripIsExact = producer.allSatisfy {
            $0.exactRoundTrip
        }
        #expect(preparation.count == 6)
        #expect(preparationIdentityIsExact)
        #expect(producer.count == 36)
        #expect(producerRoundTripIsExact)
        #expect(producer.allSatisfy { observation in
            observation.droppedPacketDelta == 0 &&
                observation.rejectedPacketDelta == 0
        })
    }

    @MainActor
    private func targetContext(
        fixture: Corpus.Case,
        route: Corpus.Route,
        limit: Int,
        primary: ProfessionalQualityPrimaryArtifacts,
        longHorizon: LongHorizonProfessionalPolicyArtifacts
    ) throws -> TargetContext {
        let director = AutonomousSessionDirector(rootSeed: fixture.rootSeed)
        var state = director.initialState()
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        var previousGraph: DSPGraphPlan?
        var horizon: LongHorizonFutureAdaptationState?
        var previousChapter: InterlockChapter?
        var predecessor: PreparedPerformancePhrase?
        var boundarySample: Int64 = 0
        for _ in 0..<limit {
            let request = PhrasePreparationRequest(
                key: PhrasePreparationKey(sessionSeed: state.rootSeed, phraseIndex: state.phraseIndex,
                    sampleRate: Double(route.sampleRate), channelCount: route.channelCount,
                    routeRecovery: route.routeRecovery, qualityRevision: state.quality.revision,
                    qualityPolicyVersion: state.quality.policyVersion,
                    qualityControllerFingerprint: state.quality.observedControllerStateFingerprint ?? state.quality.acceptedControllerStateFingerprint,
                    routeGeneration: route.routeGeneration, incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
                    incomingLiveMasterStateFingerprint: state.liveMasterHeadroom.fingerprint,
                    pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil, liveTargetStartSample: nil),
                sourceState: state, incomingLongHorizonState: horizon, incomingRenderState: renderState,
                incomingGraphState: graphState, previousGraph: previousGraph, pendingLiveMasterBinding: nil)
            let owned: PreparedPerformancePhrase?
            if let predecessor {
                owned = try predecessor.continuationAtBoundary(sessionState: state, longHorizonState: horizon,
                    sampleRate: Double(route.sampleRate), channelCount: route.channelCount,
                    routeGeneration: route.routeGeneration, actualStartSample: boundarySample).get()
            } else { owned = nil }
            predecessor = nil
            let prepared: PreparedPerformancePhrase
            if let owned { prepared = owned }
            else {
                switch AutonomousPerformancePreparer.prepareDiagnosing(request: request, director: director,
                    artifacts: primary, longHorizonArtifacts: longHorizon) {
                case .prepared(let product): prepared = product
                case .failed(let failure): throw failure
                }
            }
            guard prepared.prepared.commitEligible, prepared.continuationOwnershipIsValid
            else { throw EnvelopeError.unqualifiedProduct }
            let plan = prepared.prepared.plan
            let chapters = plan.resolvedBars.map(\.interlockChapter)
            let within = zip(chapters, chapters.dropFirst()).contains { $0.0 != $0.1 }
            let boundary = previousChapter.flatMap { prior in chapters.first.map { $0 != prior } } ?? false
            if CanonicalJourneyCheckpoint.applicable(phraseIndex: plan.phraseIndex,
                phraseKind: plan.kind, chapterChanged: within || boundary).contains(fixture.checkpoint) {
                return TargetContext(fixture: fixture, route: route, director: director,
                    request: prepared.request, reference: prepared)
            }
            let frames = try #require(Int64(exactly: prepared.prepared.audioPreflight.quality.analyzedFrameCount))
            try #require(frames > 0)
            let next = boundarySample.addingReportingOverflow(frames)
            try #require(!next.overflow)
            boundarySample = next.partialValue
            predecessor = prepared
            previousChapter = chapters.last ?? previousChapter
            state = state.advance(using: plan, quality: prepared.prepared.qualityContinuationState,
                liveMasterHeadroom: prepared.prepared.liveMasterHeadroomContinuationState,
                longHorizonDecision: prepared.longHorizonDecision)
            renderState = prepared.prepared.endingRenderState
            graphState = prepared.prepared.endingGraphState
            previousGraph = prepared.prepared.graph
            horizon = prepared.outgoingLongHorizonState
        }
        throw EnvelopeError.missingCheckpoint
    }

    @MainActor
    private func measure(
        context: TargetContext,
        trialIndex: Int,
        primary: ProfessionalQualityPrimaryArtifacts,
        longHorizon: LongHorizonProfessionalPolicyArtifacts
    ) throws -> PreparationObservation {
        let request = context.request
        let planMeasurement = timed {
            context.director.plan(
                from: request.sourceState,
                qualityRecoveryContext: request.key.routeRecovery
                    ? .neutral : request.key.qualityRecoveryContext
            )
        }
        let plan = planMeasurement.value
        let evaluator = ProfessionalQualityPreparationEvaluator(
            sampleRate: request.key.sampleRate,
            artifacts: primary
        )
        let renderMeasurement = timed {
            AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
                plan: plan,
                sessionSeed: request.sourceState.rootSeed,
                memory: request.sourceState.memory,
                sampleRate: request.key.sampleRate,
                incomingRenderState: request.incomingRenderState,
                incomingGraphState: request.incomingGraphState,
                previousGraph: request.previousGraph,
                incomingQualityState: request.sourceState.quality,
                routeRecovery: request.key.routeRecovery,
                routeChannelCount: request.key.channelCount,
                routeGeneration: request.key.routeGeneration,
                pendingLiveMasterBinding: request.pendingLiveMasterBinding,
                liveTargetStartSample: request.key.liveTargetStartSample,
                evaluator: evaluator,
                cancellationRequested: { false }
            )
        }
        let direct = try #require(renderMeasurement.value.preparedPhrase)
        let incomingLongHorizon = try #require(
            request.incomingLongHorizonState ??
            LongHorizonFutureAdaptationState(
                startingState: request.sourceState,
                policy: longHorizon.policy
            )
        )
        let longHorizonMeasurement = timed {
            let incoming = incomingLongHorizon
            return incoming.observing(
                prepared: direct,
                incomingState: request.sourceState,
                policy: longHorizon.policy
            )
        }
        let presentationMeasurement = timed {
            direct.blocks.map { block in
                WaveformEnvelope.fixedDB(left: block.left, right: block.right)
            }
        }
        #expect(!presentationMeasurement.value.isEmpty)

        let highWaterBefore = try processHighWaterBytes()
        let completeMeasurement = timed {
            AutonomousPerformancePreparer.prepare(
                request: request,
                director: context.director,
                artifacts: primary,
                longHorizonArtifacts: longHorizon
            )
        }
        let complete = try #require(completeMeasurement.value)
        let highWaterAfter = try processHighWaterBytes()
        let renderPassCount = direct.correctionRenderCount + 1
        let budget = try #require(AutonomousPreparationResourceBudget(
            sampleRate: request.key.sampleRate,
            barCount: plan.resolvedBars.count,
            renderPassCount: renderPassCount
        ))
        let maximumBudget = try #require(AutonomousPreparationResourceBudget(
            sampleRate: request.key.sampleRate,
            barCount: plan.resolvedBars.count,
            renderPassCount: QualityQualificationContract.maximumRenderPasses
        ))
        let frameCount = direct.blocks.reduce(0) { $0 + $1.left.count }
        let audioDurationNanoseconds = UInt64((
            Double(frameCount) / request.key.sampleRate * 1_000_000_000
        ).rounded())
        let directSampleHash = direct.audioPreflight.quality.sampleHash
        let completeSampleHash = complete.prepared.audioPreflight.quality.sampleHash
        let exactIdentityMatch = directSampleHash == completeSampleHash &&
            direct.candidateEvaluationFingerprint ==
                complete.prepared.candidateEvaluationFingerprint &&
            direct.blocks == complete.prepared.blocks &&
            plan == complete.prepared.plan

        guard highWaterAfter >= highWaterBefore,
              exactIdentityMatch,
              frameCount > 0 else {
            throw EnvelopeError.invalidObservation
        }
        return PreparationObservation(
            id: context.fixture.id + "--" + context.route.id +
                "--trial-" + String(trialIndex),
            caseId: context.fixture.id,
            routeId: context.route.id,
            rootSeed: context.fixture.rootSeed,
            checkpoint: context.fixture.checkpoint.rawValue,
            continuationClass: context.fixture.continuationClass,
            trialIndex: trialIndex,
            phraseIndex: plan.phraseIndex,
            startBar: plan.startBar,
            barCount: plan.resolvedBars.count,
            frameCount: frameCount,
            sampleRate: context.route.sampleRate,
            channelCount: context.route.channelCount,
            renderPassCount: renderPassCount,
            planningNanoseconds: planMeasurement.nanoseconds,
            renderEvaluationNanoseconds: renderMeasurement.nanoseconds,
            longHorizonNanoseconds: longHorizonMeasurement.nanoseconds,
            longHorizonUpdateAvailable: longHorizonMeasurement.value != nil,
            presentationNanoseconds: presentationMeasurement.nanoseconds,
            completePreparationNanoseconds: completeMeasurement.nanoseconds,
            audioDurationNanoseconds: audioDurationNanoseconds,
            calculatedPeakWorkingBytes: budget.peakWorkingByteCount,
            calculatedMaximumPeakWorkingBytes:
                maximumBudget.peakWorkingByteCount,
            processHighWaterBytesBefore: highWaterBefore,
            processHighWaterBytesAfter: highWaterAfter,
            planFingerprint: AutonomousCandidateFingerprint.plan(plan),
            replayFingerprint: request.replayIdentity.fingerprint,
            directSampleHash: directSampleHash,
            completeSampleHash: completeSampleHash,
            directEvaluationFingerprint:
                direct.candidateEvaluationFingerprint,
            completeEvaluationFingerprint:
                complete.prepared.candidateEvaluationFingerprint,
            exactIdentityMatch: exactIdentityMatch
        )
    }

    private func producerBenchmark() throws -> [ProducerObservation] {
        var observations: [ProducerObservation] = []
        observations.reserveCapacity(
            Self.producerFrameCounts.count * Self.producerTimedTrialCount
        )
        for frameCount in Self.producerFrameCounts {
            let queue = try #require(ATLivePCMQueueCreate())
            defer { ATLivePCMQueueDestroy(queue) }
            ATLivePCMQueueSetGeneration(queue, 1, 1)
            let left = (0..<frameCount).map { Float($0) * 0.000_1 }
            let right = left.map { -$0 }
            var outputLeft = [Float](repeating: .nan, count: frameCount)
            var outputRight = outputLeft
            var metadata = ATLivePCMPacketMetadata()

            let trialRange = (-Self.producerWarmupBatchCount)..<Self.producerTimedTrialCount
            for trialIndex in trialRange {
                let droppedBefore = ATLivePCMQueueDroppedPacketCount(queue)
                let rejectedBefore = ATLivePCMQueueRejectedPacketCount(queue)
                let began = DispatchTime.now().uptimeNanoseconds
                let produced = left.withUnsafeBufferPointer { leftBuffer in
                    right.withUnsafeBufferPointer { rightBuffer in
                        var successes = 0
                        for operation in 0..<Self.producerOperationsPerBatch {
                            if ATLivePCMQueueProduceNativeStereo(
                                queue,
                                Int64(operation * frameCount),
                                leftBuffer.baseAddress,
                                rightBuffer.baseAddress,
                                UInt32(frameCount)
                            ) {
                                successes += 1
                            }
                        }
                        return successes
                    }
                }
                let ended = DispatchTime.now().uptimeNanoseconds
                var exactRoundTrip = produced ==
                    Self.producerOperationsPerBatch
                for operation in 0..<Self.producerOperationsPerBatch {
                    let consumed = outputLeft.withUnsafeMutableBufferPointer {
                        leftBuffer in
                        outputRight.withUnsafeMutableBufferPointer {
                            rightBuffer in
                            ATLivePCMQueueConsume(
                                queue,
                                &metadata,
                                leftBuffer.baseAddress,
                                rightBuffer.baseAddress,
                                UInt32(frameCount)
                            )
                        }
                    }
                    exactRoundTrip = exactRoundTrip && consumed &&
                        metadata.firstMixerSample ==
                            Int64(operation * frameCount) &&
                        metadata.frameCount == UInt32(frameCount) &&
                        outputLeft == left && outputRight == right
                }
                let droppedDelta = ATLivePCMQueueDroppedPacketCount(queue) -
                    droppedBefore
                let rejectedDelta = ATLivePCMQueueRejectedPacketCount(queue) -
                    rejectedBefore
                guard exactRoundTrip,
                      droppedDelta == 0,
                      rejectedDelta == 0,
                      ended > began else {
                    throw EnvelopeError.invalidProducerObservation
                }
                if trialIndex >= 0 {
                    observations.append(ProducerObservation(
                        id: "native-stereo-" + String(frameCount) +
                            "--trial-" + String(trialIndex),
                        frameCount: frameCount,
                        trialIndex: trialIndex,
                        operationCount: Self.producerOperationsPerBatch,
                        batchNanoseconds: ended - began,
                        droppedPacketDelta: droppedDelta,
                        rejectedPacketDelta: rejectedDelta,
                        exactRoundTrip: exactRoundTrip
                    ))
                }
            }
        }
        return observations
    }

    private func timed<T>(_ body: () -> T) -> (
        value: T, nanoseconds: UInt64
    ) {
        let began = DispatchTime.now().uptimeNanoseconds
        let value = body()
        let ended = DispatchTime.now().uptimeNanoseconds
        return (value, max(1, ended - began))
    }

    private func processHighWaterBytes() throws -> UInt64 {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0,
              usage.ru_maxrss >= 0 else {
            throw EnvelopeError.memoryUnavailable
        }
        return UInt64(usage.ru_maxrss)
    }

    private func machineIdentity() -> MachineIdentity {
        let info = ProcessInfo.processInfo
        return MachineIdentity(
            operatingSystem: "macOS",
            operatingSystemVersion: info.operatingSystemVersionString,
            hardwareModel: sysctl("hw.model") ?? "unavailable",
            processor: sysctl("machdep.cpu.brand_string") ??
                sysctl("hw.machine") ?? "unavailable",
            activeProcessorCount: info.activeProcessorCount,
            physicalMemoryBytes: info.physicalMemory,
            lowPowerModeEnabled: info.isLowPowerModeEnabled,
            thermalState: String(describing: info.thermalState)
        )
    }

    private func sysctl(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0,
              size > 1 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else {
            return nil
        }
        let content = bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: content, as: UTF8.self)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func gitHead(_ root: URL) throws -> String {
        try gitOutput(root, arguments: ["rev-parse", "HEAD"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sourceFingerprint(_ root: URL) throws -> String {
        let paths = try gitOutput(root, arguments: [
            "ls-files", "--cached", "--others", "--exclude-standard", "--",
            "Package.swift", "Sources", "Tests", "scripts",
            "docs/BASELINE_CORPUS.json", "docs/ROADMAP_EXECUTION_BASELINE.json",
        ]).split(separator: "\n").map(String.init).sorted()
        var hasher = SHA256()
        for path in paths {
            hasher.update(data: Data(path.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: try Data(
                contentsOf: root.appendingPathComponent(path)
            ))
        }
        return hasher.finalize().map {
            String(format: "%02x", $0)
        }.joined()
    }

    private func gitOutput(_ root: URL, arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path] + arguments
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw EnvelopeError.git }
        return String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
    }

    private enum EnvelopeError: Error {
        case releaseBuildRequired
        case unsupportedCorpus
        case missingCheckpoint
        case invalidObservation
        case unqualifiedProduct
        case legacyIsolatedEnvelopeUnsupported
        case invalidProducerObservation
        case memoryUnavailable
        case git
    }
}
#endif
