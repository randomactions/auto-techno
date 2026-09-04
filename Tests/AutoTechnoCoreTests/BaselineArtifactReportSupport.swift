#if canImport(CryptoKit)
import CryptoKit
import Foundation

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
#endif
