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

        for _ in 0..<limit {
            let plan = director.plan(from: state)
            let chapters = plan.resolvedBars.map(\.interlockChapter)
            let changedWithinPhrase = zip(
                chapters, chapters.dropFirst()
            ).contains { $0.0 != $0.1 }
            let changedAtBoundary = previousChapter.flatMap { prior in
                chapters.first.map { $0 != prior }
            } ?? false
            let applies = CanonicalJourneyCheckpoint.applicable(
                phraseIndex: plan.phraseIndex,
                phraseKind: plan.kind,
                chapterChanged: changedWithinPhrase || changedAtBoundary
            ).contains(fixture.checkpoint)
            let request = PhrasePreparationRequest(
                key: PhrasePreparationKey(
                    sessionSeed: state.rootSeed,
                    phraseIndex: state.phraseIndex,
                    sampleRate: Double(route.sampleRate),
                    channelCount: route.channelCount,
                    routeRecovery: route.routeRecovery,
                    qualityRevision: state.quality.revision,
                    qualityPolicyVersion: state.quality.policyVersion,
                    qualityControllerFingerprint:
                        state.quality.observedControllerStateFingerprint ??
                        state.quality.acceptedControllerStateFingerprint,
                    routeGeneration: route.routeGeneration,
                    incomingLiveMasterRevision:
                        state.liveMasterHeadroom.revision,
                    incomingLiveMasterStateFingerprint:
                        state.liveMasterHeadroom.fingerprint,
                    pendingLiveMasterProposalFingerprint: nil,
                    liveEarliestEligibleFutureSample: nil,
                    liveTargetStartSample: nil
                ),
                sourceState: state,
                incomingLongHorizonState: horizon,
                incomingRenderState: renderState,
                incomingGraphState: graphState,
                previousGraph: previousGraph,
                pendingLiveMasterBinding: nil
            )
            if applies {
                return TargetContext(
                    fixture: fixture,
                    route: route,
                    director: director,
                    request: request
                )
            }

            let prepared = try #require(AutonomousPerformancePreparer.prepare(
                request: request,
                director: director,
                artifacts: primary,
                longHorizonArtifacts: longHorizon
            ))
            previousChapter = chapters.last ?? previousChapter
            state = state.advance(
                using: prepared.prepared.plan,
                quality: prepared.prepared.qualityContinuationState,
                liveMasterHeadroom:
                    prepared.prepared.liveMasterHeadroomContinuationState,
                longHorizonDecision: prepared.longHorizonDecision
            )
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
        case invalidProducerObservation
        case memoryUnavailable
        case git
    }
}
#endif
