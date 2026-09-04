#if canImport(CryptoKit)
import AutoTechnoCore
@testable import AutoTechnoDSP
@testable import AutoTechnoTransport
import CryptoKit
import Foundation
import Testing

@Suite("Exact local baseline renders", .serialized)
struct BaselineRenderIntegrationTests {
    private struct Corpus: Decodable {
        struct Policy: Decodable { let maximumPhrases: Int }
        struct Route: Decodable { let id: String; let sampleRate: Int; let channelCount: Int; let routeGeneration: Int; let routeRecovery: Bool }
        struct Case: Decodable { let id: String; let rootSeed: UInt64; let checkpoint: CanonicalJourneyCheckpoint; let continuationClass: String }
        let corpusVersion: Int
        let checkpointPolicy: Policy
        let routes: [Route]
        let cases: [Case]
    }
    private struct Manifest: Encodable {
        let schema = "autotechno-baseline-render-manifest.v1"
        let manifestVersion = 1
        let corpusSha256: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let entries: [Entry]
    }
    private struct Entry: Encodable {
        let id, caseId, routeId: String
        let rootSeed: UInt64
        let checkpoint, continuationClass: String
        let phraseIndex, startBar: Int
        let phraseKind, stateFingerprint, planFingerprint, replayFingerprint: String
        let policyVersion, qualityOutcome: String
        let sampleRate, channelCount, frameCount: Int
        let pcmSha256, wavPath, wavSha256: String
    }

    @MainActor
    @Test("Render every corpus identity through shared accepted preparation")
    func renderAll() throws {
        guard ProcessInfo.processInfo.environment["AUTOTECHNO_RUN_BASELINE_RENDER"] == "1" else { return }
        let root = repositoryRoot
        let corpusURL = root.appendingPathComponent("docs/BASELINE_CORPUS.json")
        let corpusData = try Data(contentsOf: corpusURL)
        let corpus = try JSONDecoder().decode(Corpus.self, from: corpusData)
        let baseline = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("docs/ROADMAP_EXECUTION_BASELINE.json"))) as? [String: Any]
        let output = root.appendingPathComponent("docs/local/audio/baseline-corpus-v1", isDirectory: true)
        let report = root.appendingPathComponent("docs/local/reports/baseline-corpus-v1", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: report, withIntermediateDirectories: true)
        let primary = try ProfessionalQualityPrimaryArtifacts.load()
        let longHorizon = try LongHorizonProfessionalPolicyArtifacts.load()
        var entries: [Entry] = []
        for fixture in corpus.cases {
            for route in corpus.routes {
                entries.append(try render(fixture, route: route, limit: corpus.checkpointPolicy.maximumPhrases, primary: primary, longHorizon: longHorizon, output: output))
            }
        }
        let manifest = Manifest(
            corpusSha256: digest(corpusData),
            contractBaselineFingerprint: try #require(baseline?["snapshotFingerprint"] as? String),
            sourceFingerprint: try sourceFingerprint(root),
            gitHead: try gitHead(root),
            engineVersion: QualityQualificationContract.engineVersion,
            entries: entries.sorted { $0.id < $1.id }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(to: report.appendingPathComponent("manifest.json"), options: .atomic)
        #expect(entries.count == corpus.cases.count * corpus.routes.count)
    }

    private func render(_ fixture: Corpus.Case, route: Corpus.Route, limit: Int, primary: ProfessionalQualityPrimaryArtifacts, longHorizon: LongHorizonProfessionalPolicyArtifacts, output: URL) throws -> Entry {
        let director = AutonomousSessionDirector(rootSeed: fixture.rootSeed)
        var state = director.initialState()
        var renderState = RenderState(), graphState = GeneratedDSPContinuationState()
        var previousGraph: DSPGraphPlan?, horizon: LongHorizonFutureAdaptationState?
        var previousChapter: InterlockChapter?
        for _ in 0..<limit {
            let request = PhrasePreparationRequest(
                key: PhrasePreparationKey(sessionSeed: state.rootSeed, phraseIndex: state.phraseIndex, sampleRate: Double(route.sampleRate), channelCount: route.channelCount, routeRecovery: route.routeRecovery, qualityRevision: state.quality.revision, qualityPolicyVersion: state.quality.policyVersion, qualityControllerFingerprint: state.quality.observedControllerStateFingerprint ?? state.quality.acceptedControllerStateFingerprint, routeGeneration: route.routeGeneration, incomingLiveMasterRevision: state.liveMasterHeadroom.revision, incomingLiveMasterStateFingerprint: state.liveMasterHeadroom.fingerprint, pendingLiveMasterProposalFingerprint: nil, liveEarliestEligibleFutureSample: nil, liveTargetStartSample: nil),
                sourceState: state, incomingLongHorizonState: horizon, incomingRenderState: renderState, incomingGraphState: graphState, previousGraph: previousGraph, pendingLiveMasterBinding: nil)
            let prepared = try #require(AutonomousPerformancePreparer.prepare(request: request, director: director, artifacts: primary, longHorizonArtifacts: longHorizon))
            let plan = prepared.prepared.plan
            let chapters = plan.resolvedBars.map(\.interlockChapter)
            let changed = zip(chapters, chapters.dropFirst()).contains { $0.0 != $0.1 } || (previousChapter.flatMap { p in chapters.first.map { $0 != p } } ?? false)
            if CanonicalJourneyCheckpoint.applicable(phraseIndex: plan.phraseIndex, phraseKind: plan.kind, chapterChanged: changed).contains(fixture.checkpoint) {
                return try write(prepared, fixture: fixture, route: route, output: output)
            }
            previousChapter = chapters.last ?? previousChapter
            state = state.advance(using: plan, quality: prepared.prepared.qualityContinuationState, liveMasterHeadroom: prepared.prepared.liveMasterHeadroomContinuationState, longHorizonDecision: prepared.longHorizonDecision)
            renderState = prepared.prepared.endingRenderState
            graphState = prepared.prepared.endingGraphState
            previousGraph = prepared.prepared.graph
            horizon = prepared.outgoingLongHorizonState
        }
        throw RenderError.missingCheckpoint
    }

    private func write(_ product: PreparedPerformancePhrase, fixture: Corpus.Case, route: Corpus.Route, output: URL) throws -> Entry {
        var pcm = Data()
        for block in product.prepared.blocks {
            guard block.left.count == block.right.count else { throw RenderError.invalidPCM }
            for index in block.left.indices {
                let values = [block.left[index], block.right[index]]
                guard values.allSatisfy(\.isFinite) else { throw RenderError.invalidPCM }
                for value in values { var bits = value.bitPattern.littleEndian; withUnsafeBytes(of: &bits) { pcm.append(contentsOf: $0) } }
            }
        }
        let id = fixture.id + "--" + route.id
        let wav = wave(pcm: pcm, rate: route.sampleRate)
        let filename = id + ".wav"
        try wav.write(to: output.appendingPathComponent(filename), options: .atomic)
        return Entry(id: id, caseId: fixture.id, routeId: route.id, rootSeed: fixture.rootSeed, checkpoint: fixture.checkpoint.rawValue, continuationClass: fixture.continuationClass, phraseIndex: product.prepared.plan.phraseIndex, startBar: product.prepared.plan.startBar, phraseKind: product.prepared.plan.kind.rawValue, stateFingerprint: AutonomousCandidateFingerprint.sessionState(product.request.sourceState), planFingerprint: AutonomousCandidateFingerprint.plan(product.prepared.plan), replayFingerprint: product.request.replayIdentity.fingerprint, policyVersion: product.prepared.qualityDecision.policyVersion, qualityOutcome: product.prepared.qualityDecision.outcome.rawValue, sampleRate: route.sampleRate, channelCount: route.channelCount, frameCount: pcm.count / 8, pcmSha256: digest(pcm), wavPath: "docs/local/audio/baseline-corpus-v1/" + filename, wavSha256: digest(wav))
    }

    private func wave(pcm: Data, rate: Int) -> Data {
        var data = Data(); func text(_ s: String) { data.append(s.data(using: .ascii)!) }; func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }; func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36 + pcm.count)); text("WAVEfmt "); u32(16); u16(3); u16(2); u32(UInt32(rate)); u32(UInt32(rate * 8)); u16(8); u16(32); text("data"); u32(UInt32(pcm.count)); data.append(pcm); return data
    }
    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private var repositoryRoot: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func gitHead(_ root: URL) throws -> String { let p = Process(); let pipe = Pipe(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git"); p.arguments = ["-C", root.path, "rev-parse", "HEAD"]; p.standardOutput = pipe; try p.run(); p.waitUntilExit(); guard p.terminationStatus == 0 else { throw RenderError.git }; return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
    private func sourceFingerprint(_ root: URL) throws -> String { let fm = FileManager.default; let roots = ["Package.swift", "Sources", "docs/BASELINE_CORPUS.json", "docs/ROADMAP_EXECUTION_BASELINE.json"]; var paths: [String] = []; for item in roots { let url = root.appendingPathComponent(item); var directory: ObjCBool = false; if fm.fileExists(atPath: url.path, isDirectory: &directory), directory.boolValue { paths += (fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? []).filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }.map { $0.path.replacingOccurrences(of: root.path + "/", with: "") } } else { paths.append(item) } }; var data = Data(); for path in paths.sorted() { data.append(Data(path.utf8)); data.append(0); data.append(try Data(contentsOf: root.appendingPathComponent(path))) }; return digest(data) }
    private enum RenderError: Error { case missingCheckpoint, invalidPCM, git }
}
#endif
