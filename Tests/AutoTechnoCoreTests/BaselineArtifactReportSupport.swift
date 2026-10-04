#if canImport(CryptoKit)
import CryptoKit
import Foundation
import ObjectiveC
import AutoTechnoCore
@testable import AutoTechnoDSP

struct BaselineWholeManifest: Decodable {
    struct Entry: Decodable {
        let id: String
        let caseId: String
        let routeId: String
        let rootSeed: UInt64
        let checkpoint: String
        let continuationClass: String
        let phraseIndex: Int
        let startBar: Int
        let phraseKind: String
        let stateFingerprint: String
        let planFingerprint: String
        let replayFingerprint: String
        let policyVersion: String
        let qualityOutcome: String
        let sampleRate: Int
        let channelCount: Int
        let frameCount: Int
        let pcmSha256: String
        let wavPath: String
        let wavSha256: String
    }
    let schema: String
    let contractBaselineFingerprint: String
    let sourceFingerprint: String
    let gitHead: String
    let engineVersion: String
    let entries: [Entry]
}

struct BaselineStemManifest: Decodable {
    struct Entry: Decodable {
        struct File: Decodable {
            let signal: String
            let classification: String
            let sampleRate: Int
            let channelCount: Int
            let frameCount: Int
            let pcmSha256: String
            let wavPath: String
            let wavSha256: String
        }
        let id: String
        let caseId: String
        let routeId: String
        let rootSeed: UInt64
        let checkpoint: String
        let continuationClass: String
        let phraseIndex: Int
        let startBar: Int
        let phraseKind: String
        let stateFingerprint: String
        let planFingerprint: String
        let replayFingerprint: String
        let policyVersion: String
        let qualityOutcome: String
        let sampleRate: Int
        let wholeMixChannelCount: Int
        let frameCount: Int
        let wholeMixPcmSha256: String
        let files: [File]
    }
    let schema: String
    let contractBaselineFingerprint: String
    let sourceFingerprint: String
    let gitHead: String
    let engineVersion: String
    let entries: [Entry]
}

struct BaselineReportInput: Encodable {
    let domain: String
    let manifestPath: String
    let manifestSha256: String
    let manifestSchema: String
    let assetCount: Int
    let pcmSetFingerprint: String
}

struct BaselineReportAssetSource {
    let assetId: String
    let domain: String
    let entryId: String
    let signal: String
    let classification: String
    let sampleRate: Int
    let channelCount: Int
    let frameCount: Int
    let pcmSha256: String
    let wavPath: String
    let wavSha256: String
}

struct BaselineArtifactInputs {
    let sources: [BaselineReportAssetSource]
    let wholeSources: [BaselineReportAssetSource]
    let stemSources: [BaselineReportAssetSource]
    let wholeData: Data
    let stemData: Data
    let whole: BaselineWholeManifest
    let stems: BaselineStemManifest
    let contractFingerprint: String
}

enum BaselineArtifactReportSupport {
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func load(root: URL) throws -> BaselineArtifactInputs {
        let wholePath = root.appendingPathComponent(
            "docs/local/reports/baseline-corpus-v1/manifest.json"
        )
        let stemPath = root.appendingPathComponent(
            "docs/local/reports/baseline-stems-v1/manifest.json"
        )
        let wholeData = try Data(contentsOf: wholePath)
        let stemData = try Data(contentsOf: stemPath)
        let whole = try JSONDecoder().decode(
            BaselineWholeManifest.self,
            from: wholeData
        )
        let stems = try JSONDecoder().decode(
            BaselineStemManifest.self,
            from: stemData
        )
        guard let baseline = try JSONSerialization.jsonObject(with: Data(
            contentsOf: root.appendingPathComponent(
                "docs/ROADMAP_EXECUTION_BASELINE.json"
            )
        )) as? [String: Any],
              let contractFingerprint = baseline["snapshotFingerprint"] as? String,
              whole.contractBaselineFingerprint == contractFingerprint,
              stems.contractBaselineFingerprint == contractFingerprint,
              stems.sourceFingerprint == whole.sourceFingerprint,
              stems.gitHead == whole.gitHead,
              stems.engineVersion == whole.engineVersion else {
            throw SupportError.incompatibleProvenance
        }
        let wholeSources = whole.entries.map { entry in
            BaselineReportAssetSource(
                assetId: entry.id + "::whole-mix",
                domain: "whole-mix",
                entryId: entry.id,
                signal: "whole-mix",
                classification: "whole-mix",
                sampleRate: entry.sampleRate,
                channelCount: entry.channelCount,
                frameCount: entry.frameCount,
                pcmSha256: entry.pcmSha256,
                wavPath: entry.wavPath,
                wavSha256: entry.wavSha256
            )
        }
        let stemSources = stems.entries.flatMap { entry in
            entry.files.map { file in
                BaselineReportAssetSource(
                    assetId: entry.id + "::" + file.signal,
                    domain: "role-stems",
                    entryId: entry.id,
                    signal: file.signal,
                    classification: file.classification,
                    sampleRate: file.sampleRate,
                    channelCount: file.channelCount,
                    frameCount: file.frameCount,
                    pcmSha256: file.pcmSha256,
                    wavPath: file.wavPath,
                    wavSha256: file.wavSha256
                )
            }
        }
        let sources = (wholeSources + stemSources).sorted {
            $0.assetId < $1.assetId
        }
        guard Set(sources.map(\.assetId)).count == sources.count else {
            throw SupportError.duplicateAsset
        }
        return BaselineArtifactInputs(
            sources: sources,
            wholeSources: wholeSources,
            stemSources: stemSources,
            wholeData: wholeData,
            stemData: stemData,
            whole: whole,
            stems: stems,
            contractFingerprint: contractFingerprint
        )
    }

    static func inputRecords(
        _ inputs: BaselineArtifactInputs
    ) -> [BaselineReportInput] {
        [
            BaselineReportInput(
                domain: "whole-mix",
                manifestPath:
                    "docs/local/reports/baseline-corpus-v1/manifest.json",
                manifestSha256: digest(inputs.wholeData),
                manifestSchema: inputs.whole.schema,
                assetCount: inputs.wholeSources.count,
                pcmSetFingerprint: pcmSetFingerprint(inputs.wholeSources)
            ),
            BaselineReportInput(
                domain: "role-stems",
                manifestPath:
                    "docs/local/reports/baseline-stems-v1/manifest.json",
                manifestSha256: digest(inputs.stemData),
                manifestSchema: inputs.stems.schema,
                assetCount: inputs.stemSources.count,
                pcmSetFingerprint: pcmSetFingerprint(inputs.stemSources)
            ),
        ]
    }

    static func loadWAV(
        _ source: BaselineReportAssetSource,
        root: URL
    ) throws -> [[Float]] {
        let data = try Data(contentsOf: root.appendingPathComponent(source.wavPath))
        guard data.count >= 44,
              fourCC(data, at: 0) == "RIFF",
              fourCC(data, at: 8) == "WAVE",
              fourCC(data, at: 12) == "fmt ",
              u32(data, at: 16) == 16,
              u16(data, at: 20) == 3,
              fourCC(data, at: 36) == "data" else {
            throw SupportError.invalidWAV(source.assetId)
        }
        let channelCount = Int(u16(data, at: 22))
        let sampleRate = Int(u32(data, at: 24))
        let blockAlign = Int(u16(data, at: 32))
        let bits = Int(u16(data, at: 34))
        let pcmCount = Int(u32(data, at: 40))
        guard channelCount == source.channelCount,
              sampleRate == source.sampleRate,
              bits == 32,
              blockAlign == channelCount * 4,
              pcmCount == data.count - 44,
              Int(u32(data, at: 4)) == data.count - 8,
              pcmCount % blockAlign == 0,
              pcmCount / blockAlign == source.frameCount,
              digest(data) == source.wavSha256 else {
            throw SupportError.invalidWAV(source.assetId)
        }
        let pcm = data.subdata(in: 44..<data.count)
        guard digest(pcm) == source.pcmSha256 else {
            throw SupportError.invalidPCM(source.assetId)
        }
        var channels = [[Float]](repeating: [], count: channelCount)
        for index in channels.indices {
            channels[index].reserveCapacity(source.frameCount)
        }
        for frame in 0..<source.frameCount {
            for channel in 0..<channelCount {
                let offset = 44 + (frame * channelCount + channel) * 4
                channels[channel].append(Float(bitPattern: u32(data, at: offset)))
            }
        }
        return channels
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func pcmSetFingerprint(
        _ sources: [BaselineReportAssetSource]
    ) -> String {
        var hasher = SHA256()
        for source in sources.sorted(by: { $0.assetId < $1.assetId }) {
            hasher.update(data: Data(source.assetId.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: Data(source.pcmSha256.utf8))
            hasher.update(data: Data([10]))
        }
        return hasher.finalize().map {
            String(format: "%02x", $0)
        }.joined()
    }

    private static func fourCC(_ data: Data, at offset: Int) -> String {
        String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
    }

    private static func u16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func u32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) |
            UInt32(data[offset + 1]) << 8 |
            UInt32(data[offset + 2]) << 16 |
            UInt32(data[offset + 3]) << 24
    }

    private enum SupportError: Error {
        case incompatibleProvenance
        case duplicateAsset
        case invalidWAV(String)
        case invalidPCM(String)
    }
}

/// A local-only witness attached by the actual opt-in exporter. It observes the
/// existing initialization and writes no score, PCM, continuation or policy.
final class BaselineProducerCaptureWitness {
    struct InitialState: Codable, Equatable {
        let id: String
        let rootSeedHex: String
        let sampleRate: Int
        let channelCount: Int
        let routeGeneration: Int
        let routeRecovery: Bool
        let sessionStateFingerprint: String
        let renderStateFingerprint: String
        let graphStateFingerprint: String
    }
    struct Declaration: Decodable {
        let schema: String
        let familyId: String
        let dependencySnapshotFingerprint: String
        let gitHead: String
        let contractBaselineFingerprint: String
        let producerInputs: [String: String]
        let producerContext: [String: String]
        let upstreamProducerFingerprints: [String: String]
        let producerFingerprint: String
        let compiledImagePath: String
        let compiledImageSha256: String
        let captureCorpusPath: String
        let captureCorpusSha256: String
        let initialStates: [InitialState]
        let captureEnvironmentSha256: String
    }
    private final class ImageAnchor: NSObject {}
    private let root: URL
    private let declaration: Declaration
    private let declarationURL: URL
    private let declarationSha256: String
    private let environmentSha256: String
    private let arguments: [String]
    private var observed: [InitialState] = []

    enum WitnessError: Error {
        case invalidDeclaration, invalidPath, sourceChanged, compiledImageChanged
        case existingOutput, stateMismatch, incompleteCapture, unavailableImage
    }

    static func canonical<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    static func canonicalObject(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value,
            options: [.sortedKeys, .withoutEscapingSlashes])
    }
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func writeFresh(_ data: Data, to path: URL) throws {
        // Foundation forbids combining atomic and withoutOverwriting. Exclusive
        // creation protects existing receipts; a failed partial receipt has no
        // authority and is rejected by the driver's exact-byte verification.
        try data.write(to: path, options: .withoutOverwriting)
        guard try fileDigest(path, maximumBytes: 8 * 1024 * 1024) == digest(data) else {
            throw WitnessError.sourceChanged
        }
    }
    static func captureEnvironment(_ environment: [String: String]) throws -> String {
        // These three controls only address this detached witness/probe; the
        // complete actual environment is separately hashed in the final record.
        let controls = Set(["AUTOTECHNO_BASELINE_DEPENDENCY_DECLARATION",
            "AUTOTECHNO_RUN_PRODUCER_WITNESS_PROBE", "AUTOTECHNO_PRODUCER_WITNESS_PROBE_OUTPUT"])
        return digest(try canonical(environment.filter { !controls.contains($0.key) }))
    }
    static func initialState(id: String, rootSeed: UInt64, sampleRate: Int,
        channelCount: Int, routeGeneration: Int, routeRecovery: Bool,
        state: AutonomousSessionState, render: RenderState,
        graph: GeneratedDSPContinuationState) -> InitialState {
        InitialState(id: id, rootSeedHex: String(format: "%016llx", rootSeed),
            sampleRate: sampleRate, channelCount: channelCount,
            routeGeneration: routeGeneration, routeRecovery: routeRecovery,
            sessionStateFingerprint: AutonomousCandidateFingerprint.sessionState(state),
            renderStateFingerprint: AutonomousCandidateFingerprint.renderState(render),
            graphStateFingerprint: AutonomousCandidateFingerprint.generatedDSPState(graph))
    }
    static func loadedImage() throws -> URL {
        guard String(reflecting: ImageAnchor.self).hasPrefix("AutoTechnoCoreTests."),
              let name = class_getImageName(ImageAnchor.self) else {
            throw WitnessError.unavailableImage
        }
        // The image containing this class, rather than SwiftPM's host runner.
        return URL(fileURLWithPath: String(cString: name))
            .standardizedFileURL.resolvingSymlinksInPath()
    }
    static func fileDigest(_ path: URL, maximumBytes: Int = 64 * 1024 * 1024) throws -> String {
        let values = try path.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= maximumBytes else { throw WitnessError.invalidPath }
        let handle = try FileHandle(forReadingFrom: path)
        defer { try? handle.close() }
        var hasher = SHA256(), count = 0
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
            count += data.count
            guard count <= maximumBytes else { throw WitnessError.invalidPath }
            hasher.update(data: data)
        }
        guard count == size else { throw WitnessError.sourceChanged }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
    static func localURL(_ name: String, root: URL, localOnly: Bool = false) throws -> URL {
        let parts = name.split(separator: "/", omittingEmptySubsequences: false)
        guard !name.isEmpty, !name.hasPrefix("/"), !name.contains("\\"),
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
              !name.unicodeScalars.contains(where: { $0.value < 32 }),
              !localOnly || name.hasPrefix("docs/local/") else { throw WitnessError.invalidPath }
        var result = root
        for part in parts {
            result.appendPathComponent(String(part))
            guard (try? result.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
                throw WitnessError.invalidPath
            }
        }
        return result
    }
    private init(root: URL, declarationURL: URL, declarationData: Data,
                 declaration: Declaration, environment: [String: String], arguments: [String]) throws {
        self.root = root
        self.declarationURL = declarationURL
        self.declarationSha256 = Self.digest(declarationData)
        self.declaration = declaration
        self.environmentSha256 = try Self.captureEnvironment(environment)
        self.arguments = arguments
    }
    static func begin(root: URL, family: String, corpusURL: URL,
        outputDirectories: [URL], environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = CommandLine.arguments) throws -> BaselineProducerCaptureWitness? {
        guard let relative = environment["AUTOTECHNO_BASELINE_DEPENDENCY_DECLARATION"] else { return nil }
        let path = try localURL(relative, root: root, localOnly: true)
        guard let size = try path.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 8 * 1024 * 1024 else { throw WitnessError.invalidDeclaration }
        let data = try Data(contentsOf: path)
        let declaration = try JSONDecoder().decode(Declaration.self, from: data)
        guard declaration.schema == "autotechno-baseline-producer-declaration.v1",
              declaration.familyId == family,
              !declaration.producerInputs.isEmpty,
              declaration.producerInputs.count <= 4096,
              !declaration.initialStates.isEmpty,
              declaration.initialStates.count <= 256,
              declaration.initialStates.map(\.id) == declaration.initialStates.map(\.id).sorted(),
              Set(declaration.initialStates.map(\.id)).count == declaration.initialStates.count,
              declaration.captureEnvironmentSha256 == (try captureEnvironment(environment)),
              try localURL(declaration.captureCorpusPath, root: root) == corpusURL,
              declaration.captureCorpusSha256 == (try fileDigest(corpusURL)),
              declaration.producerContext["captureCorpusPath"] == declaration.captureCorpusPath,
              declaration.producerContext["captureCorpusSha256"] == declaration.captureCorpusSha256,
              declaration.producerContext["compiledImageSha256"] == declaration.compiledImageSha256,
              declaration.producerContext["captureEnvironmentFingerprint"] == declaration.captureEnvironmentSha256,
              declaration.producerContext["initialStateFingerprint"] ==
                digest(try canonical(declaration.initialStates)) else { throw WitnessError.invalidDeclaration }
        let identity: [String: Any] = ["files": declaration.producerInputs,
            "context": declaration.producerContext, "upstream": declaration.upstreamProducerFingerprints]
        guard digest(try canonicalObject(identity)) == declaration.producerFingerprint else {
            throw WitnessError.invalidDeclaration
        }
        for directory in outputDirectories {
            guard !FileManager.default.fileExists(atPath: directory.path) else { throw WitnessError.existingOutput }
        }
        let witness = try BaselineProducerCaptureWitness(root: root, declarationURL: path,
            declarationData: data, declaration: declaration, environment: environment, arguments: arguments)
        try witness.verifyInputs()
        return witness
    }
    private func verifyInputs() throws {
        guard try Self.fileDigest(Self.localURL(declaration.captureCorpusPath, root: root)) == declaration.captureCorpusSha256 else {
            throw WitnessError.sourceChanged
        }
        guard try Self.fileDigest(declarationURL, maximumBytes: 8 * 1024 * 1024) == declarationSha256,
              try Self.captureEnvironment(ProcessInfo.processInfo.environment) == environmentSha256 else {
            throw WitnessError.sourceChanged
        }
        // Derive the conservative producer closure independently; a resealed
        // declaration cannot omit a helper or compiled test from this witness.
        let baselineURL = try Self.localURL("docs/ROADMAP_EXECUTION_BASELINE.json", root: root)
        let baselineData = try Data(contentsOf: baselineURL)
        let baseline = try JSONSerialization.jsonObject(with: baselineData) as? [String: Any]
        guard let documents = baseline?["documents"] as? [[String: Any]],
              baseline?["snapshotFingerprint"] as? String == declaration.contractBaselineFingerprint else {
            throw WitnessError.sourceChanged
        }
        let navigation = Set(["docs/codebase-map.json", "docs/CODEBASE_MAP.md"])
        var expected = Set(["AGENTS.md", "LICENSE", "docs/BASELINE_DEPENDENCY_CONTRACT.md",
            "docs/BASELINE_LIFECYCLE_POLICY.json", "scripts/baseline_dependency_contract.py",
            "scripts/baseline_capture_transaction.py", "scripts/baseline_producer_witness.py",
            "scripts/baseline_producer_capture_driver.py", "scripts/baseline_lifecycle_policy.py"])
        for document in documents {
            guard let path = document["path"] as? String else { throw WitnessError.invalidDeclaration }
            if !navigation.contains(path) { expected.insert(path) }
        }
        let inventoryProcess = Process(), inventoryPipe = Pipe()
        inventoryProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        inventoryProcess.arguments = ["--no-replace-objects", "-C", root.path,
            "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
        inventoryProcess.standardOutput = inventoryPipe
        try inventoryProcess.run()
        let inventoryData = inventoryPipe.fileHandleForReading.readDataToEndOfFile()
        inventoryProcess.waitUntilExit()
        guard inventoryProcess.terminationStatus == 0, inventoryData.count <= 1024 * 1024 else {
            throw WitnessError.invalidDeclaration
        }
        let inventory = String(decoding: inventoryData, as: UTF8.self).split(separator: "\0")
        guard inventory.count <= 4096 else { throw WitnessError.invalidDeclaration }
        for item in inventory {
            let name = String(item)
            if name == "Package.swift" || name == "Package.resolved" ||
                name.hasPrefix("Sources/") || name.hasPrefix("Tests/") || name.hasPrefix("packaging/") ||
                (name.hasPrefix("scripts/") && !name.hasSuffix(".py")) { expected.insert(name) }
        }
        guard Set(declaration.producerInputs.keys) == expected else { throw WitnessError.invalidDeclaration }
        for (name, sha) in declaration.producerInputs {
            guard try Self.fileDigest(Self.localURL(name, root: root)) == sha else { throw WitnessError.sourceChanged }
        }
        let image = try Self.loadedImage()
        guard image.path == declaration.compiledImagePath,
              try Self.fileDigest(image, maximumBytes: 512 * 1024 * 1024) == declaration.compiledImageSha256 else { throw WitnessError.compiledImageChanged }
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["--no-replace-objects", "-C", root.path, "rev-parse", "HEAD"]
        process.standardOutput = pipe
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0,
              String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines) == declaration.gitHead else {
            throw WitnessError.sourceChanged
        }
    }
    func record(_ state: InitialState) throws {
        guard !observed.contains(where: { $0.id == state.id }),
              declaration.initialStates.first(where: { $0.id == state.id }) == state else {
            throw WitnessError.stateMismatch
        }
        observed.append(state)
    }
    func finish(artifactURL: URL, artifactData: Data) throws {
        try verifyInputs()
        guard observed.sorted(by: { $0.id < $1.id }) == declaration.initialStates,
              try Self.fileDigest(artifactURL) == Self.digest(artifactData) else { throw WitnessError.incompleteCapture }
        let sidecar = artifactURL.deletingLastPathComponent().appendingPathComponent("producer-witness.json")
        guard !FileManager.default.fileExists(atPath: sidecar.path) else { throw WitnessError.existingOutput }
        let value: [String: Any] = ["schema": "autotechno-baseline-producer-witness.v1",
            "familyId": declaration.familyId, "gitHead": declaration.gitHead,
            "contractBaselineFingerprint": declaration.contractBaselineFingerprint,
            "dependencySnapshotFingerprint": declaration.dependencySnapshotFingerprint,
            "producerFingerprint": declaration.producerFingerprint,
            "declarationSha256": declarationSha256,
            "compiledImagePath": declaration.compiledImagePath,
            "compiledImageSha256": declaration.compiledImageSha256,
            "captureCorpusSha256": declaration.captureCorpusSha256,
            "captureEnvironmentSha256": environmentSha256,
            "actualEnvironmentSha256": Self.digest(try Self.canonical(ProcessInfo.processInfo.environment)),
            "actualArguments": arguments, "initialStates": try JSONSerialization.jsonObject(with: Self.canonical(declaration.initialStates)),
            "artifactSha256": Self.digest(artifactData),
            "qualification": ["artifactCurrencyEstablished": false, "promotionAuthorized": false, "runtimeInput": false]]
        let data = try Self.canonicalObject(value)
        try Self.writeFresh(data, to: sidecar)
    }
}

#endif
