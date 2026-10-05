#if canImport(CryptoKit)
import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Offline producer witness controls", .serialized)
struct BaselineProducerWitnessTests {
    private struct ProbeCorpus: Decodable {
        struct Case: Decodable { let id: String; let rootSeed: UInt64 }
        struct Route: Decodable {
            let id: String; let sampleRate: Int; let channelCount: Int
            let routeGeneration: Int; let routeRecovery: Bool
        }
        let cases: [Case]
        let routes: [Route]
    }
    @MainActor
    @Test("Producer canonical JSON is independently known and route changes bind state")
    func canonicalAndInitialState() throws {
        let data = try BaselineProducerCaptureWitness.objectJSON(
            ["upstream": [String: String](), "files": ["a/b": "x"], "context": ["sdk": "a"]])
        #expect(String(decoding: data, as: UTF8.self) ==
            "{\"context\":{\"sdk\":\"a\"},\"files\":{\"a/b\":\"x\"},\"upstream\":{}}")
        let identity = BaselineProducerCaptureWitness.ProducerIdentity(
            files: ["Z": "last", "a": "first", "X2": "two", "X10": "ten"],
            context: ["sdk": "a"], upstream: [:])
        // Independently frozen Python canonical bytes/hash: mixed case and
        // numeric suffixes expose Foundation JSONSerialization collation drift.
        #expect(try BaselineProducerCaptureWitness.digest(
            BaselineProducerCaptureWitness.canonical(identity)) ==
            "91fea5c81533ba30f42e0cde07edf9275e4ecff30eb6a969c846652ed39da991")
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState(), render = RenderState()
        let graph = GeneratedDSPContinuationState()
        let first = BaselineProducerCaptureWitness.initialState(id: "fixture--route", rootSeed: 42,
            sampleRate: 44100, channelCount: 2, routeGeneration: 0, routeRecovery: false,
            state: state, render: render, graph: graph)
        let repeatValue = BaselineProducerCaptureWitness.initialState(id: "fixture--route", rootSeed: 42,
            sampleRate: 44100, channelCount: 2, routeGeneration: 0, routeRecovery: false,
            state: state, render: render, graph: graph)
        let changed = BaselineProducerCaptureWitness.initialState(id: "fixture--route", rootSeed: 42,
            sampleRate: 48000, channelCount: 2, routeGeneration: 1, routeRecovery: true,
            state: state, render: render, graph: graph)
        #expect(first == repeatValue)
        #expect(first != changed)
        #expect(first.rootSeedHex == "000000000000002a")
        #expect(first.sessionStateFingerprint == AutonomousCandidateFingerprint.sessionState(state))
    }
    @Test("Known environment controls are metadata-only; actual capture inputs still bind")
    func environmentAndPathControls() throws {
        let first = ["AUTOTECHNO_CAPTURE_CORPUS": "docs/BASELINE_CORPUS.json", "PATH": "/fixture"]
        var second = first
        second["AUTOTECHNO_BASELINE_DEPENDENCY_DECLARATION"] = "docs/local/fixture.json"
        #expect(try BaselineProducerCaptureWitness.captureEnvironment(first) ==
            BaselineProducerCaptureWitness.captureEnvironment(second))
        second["AUTOTECHNO_CAPTURE_CORPUS"] = "docs/local/private.json"
        #expect(try BaselineProducerCaptureWitness.captureEnvironment(first) !=
            BaselineProducerCaptureWitness.captureEnvironment(second))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["../outside", "/outside", "docs//local/file", "docs/local/../file"] {
            #expect(throws: (any Error).self) { try BaselineProducerCaptureWitness.localURL(name, root: root) }
        }
        let target = root.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: target)
        #expect(throws: (any Error).self) { try BaselineProducerCaptureWitness.localURL("link/file", root: root) }
        let file = root.appendingPathComponent("data")
        try Data("abc".utf8).write(to: file)
        #expect(try BaselineProducerCaptureWitness.fileDigest(file) ==
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(throws: (any Error).self) { try BaselineProducerCaptureWitness.fileDigest(file, maximumBytes: 2) }
        let aliasRoot = URL(fileURLWithPath: "/private/tmp")
            .appendingPathComponent("producer-path-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: aliasRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: aliasRoot) }
        let aliasFile = aliasRoot.appendingPathComponent("data")
        try Data("abc".utf8).write(to: aliasFile)
        #expect(try BaselineProducerCaptureWitness.localURL("data", root: aliasRoot) ==
            aliasFile.standardizedFileURL.resolvingSymlinksInPath())
        let aliasTarget = aliasRoot.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: aliasTarget, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliasRoot.appendingPathComponent("link"),
            withDestinationURL: aliasTarget)
        #expect(throws: (any Error).self) {
            try BaselineProducerCaptureWitness.localURL("link/data", root: aliasRoot)
        }
    }
    @Test("Fresh receipts refuse overwriting and preserve existing bytes")
    func exclusiveReceiptCreation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("receipt.json")
        let original = Data("original".utf8)
        try BaselineProducerCaptureWitness.writeFresh(original, to: path)
        #expect(throws: (any Error).self) {
            try BaselineProducerCaptureWitness.writeFresh(Data("replacement".utf8), to: path)
        }
        #expect(try Data(contentsOf: path) == original)
    }
    @Test("Loaded test image is actual package image and has bounded streamed bytes")
    func actualImageIdentity() throws {
        let image = try BaselineProducerCaptureWitness.loadedImage()
        #expect(image.lastPathComponent.contains("AutoTechno"))
        #expect(try BaselineProducerCaptureWitness.fileDigest(image, maximumBytes: 512 * 1024 * 1024).count == 64)
    }
    @MainActor
    @Test("Explicit local probe reports actual initialization and process without producing audio")
    func probeActualProducerInputs() throws {
        guard ProcessInfo.processInfo.environment["AUTOTECHNO_RUN_PRODUCER_WITNESS_PROBE"] == "1" else {
            // Opt-in body is not native capture, capacity or qualification proof.
            return
        }
        let root = BaselineArtifactReportSupport.repositoryRoot
        let name = ProcessInfo.processInfo.environment["AUTOTECHNO_CAPTURE_CORPUS"] ?? "docs/BASELINE_CORPUS.json"
        let corpusURL = try BaselineProducerCaptureWitness.localURL(name, root: root)
        let corpusData = try Data(contentsOf: corpusURL)
        let corpus = try JSONDecoder().decode(ProbeCorpus.self, from: corpusData)
        var records: [BaselineProducerCaptureWitness.InitialState] = []
        for fixture in corpus.cases {
            for route in corpus.routes {
                let director = AutonomousSessionDirector(rootSeed: fixture.rootSeed)
                let state = director.initialState(), render = RenderState()
                let graph = GeneratedDSPContinuationState()
                records.append(BaselineProducerCaptureWitness.initialState(id: fixture.id + "--" + route.id,
                    rootSeed: fixture.rootSeed, sampleRate: route.sampleRate, channelCount: route.channelCount,
                    routeGeneration: route.routeGeneration, routeRecovery: route.routeRecovery,
                    state: state, render: render, graph: graph))
            }
        }
        records.sort { $0.id < $1.id }
        let environment = ProcessInfo.processInfo.environment
        let image = try BaselineProducerCaptureWitness.loadedImage()
        let data = try BaselineProducerCaptureWitness.canonical(records)
        let value: [String: Any] = ["schema": "autotechno-baseline-producer-probe.v1",
            "engineVersion": String(QualityQualificationContract.engineVersion),
            "initialStates": try JSONSerialization.jsonObject(with: data),
            "initialStateFingerprint": BaselineProducerCaptureWitness.digest(data),
            "captureCorpusPath": name, "captureCorpusSha256": BaselineProducerCaptureWitness.digest(corpusData),
            "captureEnvironmentSha256": try BaselineProducerCaptureWitness.captureEnvironment(environment),
            "actualEnvironmentSha256": BaselineProducerCaptureWitness.digest(try BaselineProducerCaptureWitness.canonical(environment)),
            "actualArguments": CommandLine.arguments, "compiledImagePath": image.path,
            "compiledImageSha256": try BaselineProducerCaptureWitness.fileDigest(image, maximumBytes: 512 * 1024 * 1024),
            "probeOnly": true, "artifactCurrencyEstablished": false, "promotionAuthorized": false]
        guard let output = environment["AUTOTECHNO_PRODUCER_WITNESS_PROBE_OUTPUT"] else {
            throw BaselineProducerCaptureWitness.WitnessError.invalidPath
        }
        let path = try BaselineProducerCaptureWitness.localURL(output, root: root, localOnly: true)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try BaselineProducerCaptureWitness.writeFresh(try BaselineProducerCaptureWitness.objectJSON(value), to: path)
    }
}
#endif
