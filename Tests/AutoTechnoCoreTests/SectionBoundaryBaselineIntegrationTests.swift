#if canImport(CryptoKit)
import AutoTechnoCore
@testable import AutoTechnoDSP
@testable import AutoTechnoTransport
import CryptoKit
import Foundation
import Testing

@Suite("Exact local section-boundary baseline", .serialized)
struct SectionBoundaryBaselineIntegrationTests {
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
        let checkpointPolicy: Policy
        let routes: [Route]
        let cases: [Case]
    }

    private struct WholeManifest: Decodable {
        struct Entry: Decodable {
            let id: String
            let phraseIndex: Int
            let startBar: Int
            let phraseKind: String
            let stateFingerprint: String
            let planFingerprint: String
            let replayFingerprint: String
            let sampleRate: Int
            let channelCount: Int
            let frameCount: Int
            let pcmSha256: String
        }
        let entries: [Entry]
    }

    private struct Manifest: Encodable {
        let schema = "autotechno-section-boundary-baseline-manifest.v1"
        let manifestVersion = 1
        let corpusSha256: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let analyzerVersion: String
        let wholeManifestSha256: String
        let entries: [Entry]
    }

    private struct Entry: Encodable {
        let id: String
        let caseId: String
        let routeId: String
        let rootSeed: UInt64
        let checkpoint: String
        let continuationClass: String
        let sampleRate: Int
        let channelCount: Int
        let focusPhraseIndex: Int
        let contextPhraseIndices: [Int]
        let contextStartBar: Int
        let contextBarCount: Int
        let barFrameCount: Int
        let frameCount: Int
        let targetContextStartFrame: Int
        let targetFrameCount: Int
        let targetPCMSha256: String
        let contextPCMSha256: String
        let wavPath: String
        let wavSha256: String
        let evidencePath: String
        let evidenceSha256: String
        let boundaryCount: Int
    }

    private struct PhraseIdentity: Encodable {
        let position: String
        let phraseIndex: Int
        let startBar: Int
        let barCount: Int
        let phraseKind: String
        let stateFingerprint: String
        let planFingerprint: String
        let replayFingerprint: String
    }

    private struct Artifact: Encodable {
        let schema = "autotechno-section-boundary-baseline-artifact.v1"
        let id: String
        let caseId: String
        let routeId: String
        let rootSeed: UInt64
        let checkpoint: String
        let continuationClass: String
        let wholeManifestEntryId: String
        let wholeManifestEntryPCMSha256: String
        let targetContextStartFrame: Int
        let targetFrameCount: Int
        let phrases: [PhraseIdentity]
        let evidence: PCMSectionBoundaryBaselineEvidence
    }

    @MainActor
    @Test("Export bounded continuous context through shared accepted preparation")
    func exportAll() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_SECTION_BOUNDARY_BASELINE"
        ] == "1" else { return }
        let root = repositoryRoot
        let corpusURL = root.appendingPathComponent("docs/BASELINE_CORPUS.json")
        let corpusData = try Data(contentsOf: corpusURL)
        let corpus = try JSONDecoder().decode(Corpus.self, from: corpusData)
        let snapshot = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root.appendingPathComponent(
                "docs/ROADMAP_EXECUTION_BASELINE.json"
            ))
        ) as? [String: Any]
        let wholeURL = root.appendingPathComponent(
            "docs/local/reports/baseline-corpus-v1/manifest.json"
        )
        let wholeData = try Data(contentsOf: wholeURL)
        let whole = try JSONDecoder().decode(WholeManifest.self, from: wholeData)
        let wholeByID = Dictionary(
            uniqueKeysWithValues: whole.entries.map { ($0.id, $0) }
        )
        let audio = root.appendingPathComponent(
            "docs/local/audio/section-boundary-baseline-v1",
            isDirectory: true
        )
        let report = root.appendingPathComponent(
            "docs/local/reports/section-boundary-baseline-v1",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: audio,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: report,
            withIntermediateDirectories: true
        )
        let primary = try ProfessionalQualityPrimaryArtifacts.load()
        let longHorizon = try LongHorizonProfessionalPolicyArtifacts.load()
        var entries: [Entry] = []
        for fixture in corpus.cases {
            for route in corpus.routes {
                let id = fixture.id + "--" + route.id
                entries.append(try export(
                    fixture,
                    route: route,
                    limit: corpus.checkpointPolicy.maximumPhrases,
                    primary: primary,
                    longHorizon: longHorizon,
                    whole: #require(wholeByID[id]),
                    audio: audio,
                    report: report
                ))
            }
        }
        let manifest = Manifest(
            corpusSha256: digest(corpusData),
            contractBaselineFingerprint: try #require(
                snapshot?["snapshotFingerprint"] as? String
            ),
            sourceFingerprint: try sourceFingerprint(root),
            gitHead: try gitHead(root),
            engineVersion: QualityQualificationContract.engineVersion,
            analyzerVersion:
                PCMSectionBoundaryBaselineAnalyzer.analyzerVersion,
            wholeManifestSha256: digest(wholeData),
            entries: entries.sorted { $0.id < $1.id }
        )
        try encoded(manifest).write(
            to: report.appendingPathComponent("manifest.json"),
            options: .atomic
        )
        #expect(entries.count == corpus.cases.count * corpus.routes.count)
        #expect(entries.allSatisfy { $0.contextPhraseIndices.count <= 3 })
        #expect(entries.allSatisfy { $0.contextBarCount <= 48 })
    }

    @MainActor
    private func export(
        _ fixture: Corpus.Case,
        route: Corpus.Route,
        limit: Int,
        primary: ProfessionalQualityPrimaryArtifacts,
        longHorizon: LongHorizonProfessionalPolicyArtifacts,
        whole: WholeManifest.Entry,
        audio: URL,
        report: URL
    ) throws -> Entry {
        let director = AutonomousSessionDirector(rootSeed: fixture.rootSeed)
        var state = director.initialState()
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        var previousGraph: DSPGraphPlan?
        var horizon: LongHorizonFutureAdaptationState?
        var previousChapter: InterlockChapter?
        var previous: PreparedPerformancePhrase?
        for _ in 0..<limit {
            let request = makeRequest(
                state: state,
                route: route,
                horizon: horizon,
                renderState: renderState,
                graphState: graphState,
                previousGraph: previousGraph
            )
            let current = try #require(AutonomousPerformancePreparer.prepare(
                request: request,
                director: director,
                artifacts: primary,
                longHorizonArtifacts: longHorizon
            ))
            let plan = current.prepared.plan
            let chapters = plan.resolvedBars.map(\.interlockChapter)
            let chapterChanged = zip(chapters, chapters.dropFirst()).contains {
                $0.0 != $0.1
            } || (previousChapter.flatMap { prior in
                chapters.first.map { $0 != prior }
            } ?? false)
            if CanonicalJourneyCheckpoint.applicable(
                phraseIndex: plan.phraseIndex,
                phraseKind: plan.kind,
                chapterChanged: chapterChanged
            ).contains(fixture.checkpoint) {
                let successorState = state.advance(
                    using: plan,
                    quality: current.prepared.qualityContinuationState,
                    liveMasterHeadroom:
                        current.prepared.liveMasterHeadroomContinuationState,
                    longHorizonDecision: current.longHorizonDecision
                )
                let successorRequest = makeRequest(
                    state: successorState,
                    route: route,
                    horizon: current.outgoingLongHorizonState,
                    renderState: current.prepared.endingRenderState,
                    graphState: current.prepared.endingGraphState,
                    previousGraph: current.prepared.graph
                )
                let successor = try #require(
                    AutonomousPerformancePreparer.prepare(
                        request: successorRequest,
                        director: director,
                        artifacts: primary,
                        longHorizonArtifacts: longHorizon
                    )
                )
                let contexts = previous.map { [$0, current, successor] } ??
                    [current, successor]
                return try write(
                    contexts,
                    target: current,
                    fixture: fixture,
                    route: route,
                    whole: whole,
                    audio: audio,
                    report: report
                )
            }
            previous = current
            previousChapter = chapters.last ?? previousChapter
            state = state.advance(
                using: plan,
                quality: current.prepared.qualityContinuationState,
                liveMasterHeadroom:
                    current.prepared.liveMasterHeadroomContinuationState,
                longHorizonDecision: current.longHorizonDecision
            )
            renderState = current.prepared.endingRenderState
            graphState = current.prepared.endingGraphState
            previousGraph = current.prepared.graph
            horizon = current.outgoingLongHorizonState
        }
        throw ExportError.missingCheckpoint
    }

    private func makeRequest(
        state: AutonomousSessionState,
        route: Corpus.Route,
        horizon: LongHorizonFutureAdaptationState?,
        renderState: RenderState,
        graphState: GeneratedDSPContinuationState,
        previousGraph: DSPGraphPlan?
    ) -> PhrasePreparationRequest {
        PhrasePreparationRequest(
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
                incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
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
    }

    private func write(
        _ contexts: [PreparedPerformancePhrase],
        target: PreparedPerformancePhrase,
        fixture: Corpus.Case,
        route: Corpus.Route,
        whole: WholeManifest.Entry,
        audio: URL,
        report: URL
    ) throws -> Entry {
        guard (2...3).contains(contexts.count) else {
            throw ExportError.invalidContext
        }
        let targetIndex = contexts.firstIndex {
            $0.prepared.plan.phraseIndex == target.prepared.plan.phraseIndex
        }
        guard let targetIndex else { throw ExportError.invalidContext }
        var channels = [[Float](), [Float]()]
        var scoreBars: [PCMSectionBoundaryScoreBar] = []
        var phrases: [PhraseIdentity] = []
        var phraseFrameCounts: [Int] = []
        for (position, context) in contexts.enumerated() {
            let plan = context.prepared.plan
            guard plan.resolvedBars.count == context.prepared.blocks.count else {
                throw ExportError.invalidContext
            }
            let label = position < targetIndex ? "lead-in" :
                (position == targetIndex ? "focus" : "follow-through")
            phrases.append(PhraseIdentity(
                position: label,
                phraseIndex: plan.phraseIndex,
                startBar: plan.startBar,
                barCount: plan.barCount,
                phraseKind: plan.kind.rawValue,
                stateFingerprint: AutonomousCandidateFingerprint.sessionState(
                    context.request.sourceState
                ),
                planFingerprint: AutonomousCandidateFingerprint.plan(plan),
                replayFingerprint: context.request.replayIdentity.fingerprint
            ))
            var phraseFrames = 0
            for (barIndex, block) in context.prepared.blocks.enumerated() {
                guard block.left.count == block.right.count,
                      block.left.allSatisfy(\.isFinite),
                      block.right.allSatisfy(\.isFinite) else {
                    throw ExportError.invalidPCM
                }
                channels[0].append(contentsOf: block.left)
                channels[1].append(contentsOf: block.right)
                phraseFrames += block.left.count
                scoreBars.append(PCMSectionBoundaryScoreBar(
                    phraseIndex: plan.phraseIndex,
                    phraseKind: plan.kind.rawValue,
                    absoluteBar: plan.startBar + barIndex,
                    barIndexInPhrase: barIndex,
                    interlockChapter:
                        plan.resolvedBars[barIndex].interlockChapter.rawValue
                ))
            }
            phraseFrameCounts.append(phraseFrames)
        }
        let firstPhraseIndex = contexts[0].prepared.plan.phraseIndex
        let lastPhraseIndex = contexts[contexts.count - 1]
            .prepared.plan.phraseIndex
        let expectedPhraseIndices = Array(firstPhraseIndex...lastPhraseIndex)
        guard contexts.map({ $0.prepared.plan.phraseIndex }) ==
                expectedPhraseIndices,
              scoreBars.count <= PCMSectionBoundaryBaselineAnalyzer.maximumBarCount,
              let input = PCMSectionBoundaryBaselineAnalyzer.makeInput(
                channels: channels,
                sampleRate: Double(route.sampleRate),
                scoreBars: scoreBars,
                focusPhraseIndex: target.prepared.plan.phraseIndex
              ),
              let evidence = PCMSectionBoundaryBaselineAnalyzer.analyze(
                input: input
              ) else {
            throw ExportError.invalidContext
        }
        let targetStart = phraseFrameCounts.prefix(targetIndex).reduce(0, +)
        let targetFrames = phraseFrameCounts[targetIndex]
        let targetPCM = interleaved(
            left: Array(channels[0][targetStart..<(targetStart + targetFrames)]),
            right: Array(channels[1][targetStart..<(targetStart + targetFrames)])
        )
        guard whole.phraseIndex == target.prepared.plan.phraseIndex,
              whole.startBar == target.prepared.plan.startBar,
              whole.phraseKind == target.prepared.plan.kind.rawValue,
              whole.stateFingerprint == phrases[targetIndex].stateFingerprint,
              whole.planFingerprint == phrases[targetIndex].planFingerprint,
              whole.replayFingerprint == phrases[targetIndex].replayFingerprint,
              whole.sampleRate == route.sampleRate,
              whole.channelCount == route.channelCount,
              whole.frameCount == targetFrames,
              whole.pcmSha256 == digest(targetPCM) else {
            throw ExportError.wholeManifestMismatch
        }
        let id = fixture.id + "--" + route.id
        let pcm = interleaved(left: channels[0], right: channels[1])
        let wav = wave(pcm: pcm, rate: route.sampleRate)
        let wavName = id + ".wav"
        let evidenceName = id + ".json"
        try wav.write(to: audio.appendingPathComponent(wavName), options: .atomic)
        let artifact = Artifact(
            id: id,
            caseId: fixture.id,
            routeId: route.id,
            rootSeed: fixture.rootSeed,
            checkpoint: fixture.checkpoint.rawValue,
            continuationClass: fixture.continuationClass,
            wholeManifestEntryId: whole.id,
            wholeManifestEntryPCMSha256: whole.pcmSha256,
            targetContextStartFrame: targetStart,
            targetFrameCount: targetFrames,
            phrases: phrases,
            evidence: evidence
        )
        let artifactData = try encoded(artifact)
        try artifactData.write(
            to: report.appendingPathComponent(evidenceName),
            options: .atomic
        )
        return Entry(
            id: id,
            caseId: fixture.id,
            routeId: route.id,
            rootSeed: fixture.rootSeed,
            checkpoint: fixture.checkpoint.rawValue,
            continuationClass: fixture.continuationClass,
            sampleRate: route.sampleRate,
            channelCount: route.channelCount,
            focusPhraseIndex: target.prepared.plan.phraseIndex,
            contextPhraseIndices: contexts.map { $0.prepared.plan.phraseIndex },
            contextStartBar: contexts[0].prepared.plan.startBar,
            contextBarCount: scoreBars.count,
            barFrameCount: input.barFrameCount,
            frameCount: channels[0].count,
            targetContextStartFrame: targetStart,
            targetFrameCount: targetFrames,
            targetPCMSha256: digest(targetPCM),
            contextPCMSha256: digest(pcm),
            wavPath: "docs/local/audio/section-boundary-baseline-v1/" + wavName,
            wavSha256: digest(wav),
            evidencePath:
                "docs/local/reports/section-boundary-baseline-v1/" + evidenceName,
            evidenceSha256: digest(artifactData),
            boundaryCount: evidence.boundaries.count
        )
    }

    private func interleaved(left: [Float], right: [Float]) -> Data {
        var data = Data()
        data.reserveCapacity(left.count * 8)
        for index in left.indices {
            for value in [left[index], right[index]] {
                var bits = value.bitPattern.littleEndian
                withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
            }
        }
        return data
    }

    private func wave(pcm: Data, rate: Int) -> Data {
        var data = Data()
        func text(_ value: String) {
            data.append(value.data(using: .ascii)!)
        }
        func u16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func u32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        text("RIFF"); u32(UInt32(36 + pcm.count)); text("WAVEfmt ")
        u32(16); u16(3); u16(2); u32(UInt32(rate)); u32(UInt32(rate * 8))
        u16(8); u16(32); text("data"); u32(UInt32(pcm.count)); data.append(pcm)
        return data
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        return try encoder.encode(value)
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func gitHead(_ root: URL) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path, "rev-parse", "HEAD"]
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ExportError.git }
        return String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sourceFingerprint(_ root: URL) throws -> String {
        let manager = FileManager.default
        let roots = [
            "Package.swift", "Sources", "docs/BASELINE_CORPUS.json",
            "docs/ROADMAP_EXECUTION_BASELINE.json",
        ]
        var paths: [String] = []
        for item in roots {
            let url = root.appendingPathComponent(item)
            var directory: ObjCBool = false
            if manager.fileExists(atPath: url.path, isDirectory: &directory),
               directory.boolValue {
                paths += (manager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey]
                )?.allObjects as? [URL] ?? []).filter {
                    (try? $0.resourceValues(
                        forKeys: [.isRegularFileKey]
                    ).isRegularFile) == true
                }.map {
                    $0.path.replacingOccurrences(of: root.path + "/", with: "")
                }
            } else {
                paths.append(item)
            }
        }
        var data = Data()
        for path in paths.sorted() {
            data.append(Data(path.utf8)); data.append(0)
            data.append(try Data(contentsOf: root.appendingPathComponent(path)))
        }
        return digest(data)
    }

    private enum ExportError: Error {
        case missingCheckpoint
        case invalidContext
        case invalidPCM
        case wholeManifestMismatch
        case git
    }
}
#endif
