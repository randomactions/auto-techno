#if canImport(CryptoKit)
@testable import AutoTechnoDSP
import CryptoKit
import Foundation
import Testing

@Suite("Local PCM signal baseline", .serialized)
struct SignalBaselineIntegrationTests {
    private struct WholeManifest: Decodable {
        struct Entry: Decodable {
            let id: String
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

    private struct StemManifest: Decodable {
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
            let files: [File]
        }
        let schema: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let entries: [Entry]
    }

    private struct Payload: Encodable {
        let schema = "autotechno-signal-baseline-report.v1"
        let reportVersion = 1
        let analyzerVersion: String
        let corpusSha256: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let policies: Policies
        let inputs: [Input]
        let assets: [Asset]
    }

    private struct Policies: Encodable {
        let bpm: Double
        let beatsPerBar: Int
        let segmentDurationSeconds: Double
        let segmentFrameRounding: String
        let clippingAmplitude: Double
        let nearSilenceDBFS: Double
        let nearSilenceAmplitude: Double
        let float32MinimumNormal: Double
        let decibelFloor: Double
        let truePeakStandard: String
        let truePeakOversamplingFactor: Int
    }

    private struct Input: Encodable {
        let domain: String
        let manifestPath: String
        let manifestSha256: String
        let manifestSchema: String
        let assetCount: Int
        let pcmSetFingerprint: String
    }

    private struct Asset: Encodable {
        let assetId: String
        let domain: String
        let entryId: String
        let signal: String
        let classification: String
        let pcmSha256: String
        let wavPath: String
        let evidence: PCMSignalIntegrityEvidence
    }

    private struct AssetSource {
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

    @Test("Analyze every exact whole mix and role signal into one local payload")
    func export() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_SIGNAL_BASELINE"
        ] == "1" else { return }
        let root = repositoryRoot
        let wholePath = root.appendingPathComponent(
            "docs/local/reports/baseline-corpus-v1/manifest.json"
        )
        let stemPath = root.appendingPathComponent(
            "docs/local/reports/baseline-stems-v1/manifest.json"
        )
        let wholeData = try Data(contentsOf: wholePath)
        let stemData = try Data(contentsOf: stemPath)
        let whole = try JSONDecoder().decode(WholeManifest.self, from: wholeData)
        let stems = try JSONDecoder().decode(StemManifest.self, from: stemData)
        let baseline = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf:
                root.appendingPathComponent("docs/ROADMAP_EXECUTION_BASELINE.json")
            )) as? [String: Any]
        )
        let contractFingerprint = try #require(
            baseline["snapshotFingerprint"] as? String
        )
        try #require(whole.contractBaselineFingerprint == contractFingerprint)
        try #require(stems.contractBaselineFingerprint == contractFingerprint)
        try #require(stems.sourceFingerprint == whole.sourceFingerprint)
        try #require(stems.gitHead == whole.gitHead)
        try #require(stems.engineVersion == whole.engineVersion)

        let wholeSources = whole.entries.map { entry in
            AssetSource(
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
                AssetSource(
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
        try #require(Set(sources.map(\.assetId)).count == sources.count)
        var assets: [Asset] = []
        assets.reserveCapacity(sources.count)
        for source in sources {
            let channels = try loadWAV(source, root: root)
            let framesPerBar = Int(
                (Double(source.sampleRate) * 240.0 / 130.0).rounded()
            )
            let evidence = try #require(PCMSignalIntegrityAnalyzer.analyze(
                channels: channels,
                sampleRate: Double(source.sampleRate),
                segmentFrameCount: framesPerBar
            ))
            try #require(evidence.frameCount == source.frameCount)
            try #require(evidence.channelCount == source.channelCount)
            assets.append(Asset(
                assetId: source.assetId,
                domain: source.domain,
                entryId: source.entryId,
                signal: source.signal,
                classification: source.classification,
                pcmSha256: source.pcmSha256,
                wavPath: source.wavPath,
                evidence: evidence
            ))
        }

        let corpusData = try Data(contentsOf:
            root.appendingPathComponent("docs/BASELINE_CORPUS.json")
        )
        let payload = Payload(
            analyzerVersion: PCMSignalIntegrityAnalyzer.analyzerVersion,
            corpusSha256: digest(corpusData),
            contractBaselineFingerprint: contractFingerprint,
            sourceFingerprint: whole.sourceFingerprint,
            gitHead: whole.gitHead,
            engineVersion: whole.engineVersion,
            policies: Policies(
                bpm: 130,
                beatsPerBar: 4,
                segmentDurationSeconds: 240.0 / 130.0,
                segmentFrameRounding: "nearest-frame",
                clippingAmplitude: PCMSignalIntegrityAnalyzer.clippingAmplitude,
                nearSilenceDBFS: PCMSignalIntegrityAnalyzer.nearSilenceDBFS,
                nearSilenceAmplitude:
                    PCMSignalIntegrityAnalyzer.nearSilenceAmplitude,
                float32MinimumNormal:
                    PCMSignalIntegrityAnalyzer.float32MinimumNormal,
                decibelFloor: PCMSignalIntegrityAnalyzer.decibelFloor,
                truePeakStandard: PCMSignalIntegrityAnalyzer.truePeakStandard,
                truePeakOversamplingFactor:
                    PCMSignalIntegrityAnalyzer.truePeakOversamplingFactor
            ),
            inputs: [
                Input(
                    domain: "whole-mix",
                    manifestPath:
                        "docs/local/reports/baseline-corpus-v1/manifest.json",
                    manifestSha256: digest(wholeData),
                    manifestSchema: whole.schema,
                    assetCount: wholeSources.count,
                    pcmSetFingerprint: pcmSetFingerprint(wholeSources)
                ),
                Input(
                    domain: "role-stems",
                    manifestPath:
                        "docs/local/reports/baseline-stems-v1/manifest.json",
                    manifestSha256: digest(stemData),
                    manifestSchema: stems.schema,
                    assetCount: stemSources.count,
                    pcmSetFingerprint: pcmSetFingerprint(stemSources)
                ),
            ],
            assets: assets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        let output = root.appendingPathComponent(
            "docs/local/reports/signal-baseline-v1/payload.json"
        )
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(payload).write(to: output, options: .atomic)
        #expect(assets.count == 224)
        #expect(assets.allSatisfy { $0.evidence.combined.finite })
    }

    private func loadWAV(
        _ source: AssetSource,
        root: URL
    ) throws -> [[Float]] {
        let url = root.appendingPathComponent(source.wavPath)
        let data = try Data(contentsOf: url)
        guard data.count >= 44,
              fourCC(data, at: 0) == "RIFF",
              fourCC(data, at: 8) == "WAVE",
              fourCC(data, at: 12) == "fmt ",
              u32(data, at: 16) == 16,
              u16(data, at: 20) == 3,
              fourCC(data, at: 36) == "data" else {
            throw ExportError.invalidWAV(source.assetId)
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
            throw ExportError.invalidWAV(source.assetId)
        }
        let pcm = data.subdata(in: 44..<data.count)
        guard digest(pcm) == source.pcmSha256 else {
            throw ExportError.invalidPCM(source.assetId)
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

    private func pcmSetFingerprint(_ sources: [AssetSource]) -> String {
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

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func fourCC(_ data: Data, at offset: Int) -> String {
        String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
    }

    private func u16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func u32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) |
            UInt32(data[offset + 1]) << 8 |
            UInt32(data[offset + 2]) << 16 |
            UInt32(data[offset + 3]) << 24
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private enum ExportError: Error {
        case invalidWAV(String)
        case invalidPCM(String)
    }
}
#endif
