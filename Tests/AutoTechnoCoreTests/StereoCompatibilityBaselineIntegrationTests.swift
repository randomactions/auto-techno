#if canImport(CryptoKit)
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Local stereo compatibility baseline", .serialized)
struct StereoCompatibilityBaselineIntegrationTests {
    private struct Payload: Encodable {
        let schema = "autotechno-stereo-compatibility-baseline-report.v1"
        let reportVersion = 1
        let analyzerVersion: String
        let corpusSha256: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let policies: Policies
        let inputs: [BaselineReportInput]
        let assets: [Asset]
    }

    private struct Policies: Encodable {
        let bpm: Double
        let beatsPerBar: Int
        let segmentDurationSeconds: Double
        let segmentFrameRounding: String
        let eligibleSourceChannelCounts: [Int]
        let monoSourceMapping: String
        let domains: [String]
        let midSideScaling: String
        let monoFold: String
        let correlationDenominator: String
        let correlationClamp: String
        let zeroAndActivityRule: String
        let compatibilityClassification: String
        let bandEnergyModel: String
        let bandFilterCutoffsHz: [Double]
        let bandFilterReset: String
        let bandEnergyConservation: String
        let aggregation: String
        let finalSegmentPolicy: String
        let monoLevelUnit: String
        let decibelFloor: Double
        let interpretation: String
    }

    private struct Asset: Encodable {
        let assetId: String
        let domain: String
        let entryId: String
        let signal: String
        let classification: String
        let pcmSha256: String
        let wavPath: String
        let evidence: PCMStereoCompatibilityEvidence
    }

    @Test("Export exact whole and role stereo compatibility evidence")
    func export() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_STEREO_COMPATIBILITY_BASELINE"
        ] == "1" else { return }
        let root = BaselineArtifactReportSupport.repositoryRoot
        let corpusData = try Data(contentsOf: root.appendingPathComponent(
            "docs/BASELINE_CORPUS.json"
        ))
        let inputs = try BaselineArtifactReportSupport.load(root: root)
        let assets = try inputs.sources.map { source in
            let channels = try BaselineArtifactReportSupport.loadWAV(
                source,
                root: root
            )
            let segmentFrames = Int((
                Double(source.sampleRate) * 240.0 / 130.0
            ).rounded())
            guard let evidence = PCMStereoCompatibilityAnalyzer.analyze(
                    channels: channels,
                    sampleRate: Double(source.sampleRate),
                    segmentFrameCount: segmentFrames
            ) else {
                throw ExportError.unavailable(source.assetId)
            }
            return Asset(
                assetId: source.assetId,
                domain: source.domain,
                entryId: source.entryId,
                signal: source.signal,
                classification: source.classification,
                pcmSha256: source.pcmSha256,
                wavPath: source.wavPath,
                evidence: evidence
            )
        }
        let payload = Payload(
            analyzerVersion: PCMStereoCompatibilityAnalyzer.analyzerVersion,
            corpusSha256: BaselineArtifactReportSupport.digest(corpusData),
            contractBaselineFingerprint: inputs.contractFingerprint,
            sourceFingerprint: inputs.whole.sourceFingerprint,
            gitHead: inputs.whole.gitHead,
            engineVersion: inputs.whole.engineVersion,
            policies: Policies(
                bpm: 130,
                beatsPerBar: 4,
                segmentDurationSeconds: 240.0 / 130.0,
                segmentFrameRounding: "nearest-frame",
                eligibleSourceChannelCounts: [1, 2],
                monoSourceMapping: "repeat-source-channel-as-left-and-right",
                domains: PCMStereoCompatibilityAnalyzer.domainNames,
                midSideScaling: PCMStereoCompatibilityAnalyzer.midSideScaling,
                monoFold: PCMStereoCompatibilityAnalyzer.monoFold,
                correlationDenominator:
                    PCMStereoCompatibilityAnalyzer.correlationDenominator,
                correlationClamp: "closed-minus-one-to-one",
                zeroAndActivityRule: "exact-digital-zero-no-epsilon",
                compatibilityClassification:
                    PCMStereoCompatibilityAnalyzer.compatibilityClassification,
                bandEnergyModel:
                    PCMStereoCompatibilityAnalyzer.bandEnergyModel,
                bandFilterCutoffsHz: [35, 120, 420, 2_400, 10_000],
                bandFilterReset:
                    PCMStereoCompatibilityAnalyzer.bandFilterReset,
                bandEnergyConservation: "not-claimed",
                aggregation: PCMStereoCompatibilityAnalyzer.aggregation,
                finalSegmentPolicy: "analyze-nonempty-partial-segment",
                monoLevelUnit: "ten-log10-mid-over-stereo-mean-square",
                decibelFloor: PCMStereoCompatibilityAnalyzer.decibelFloor,
                interpretation: "descriptive-structural-not-artistic-ranking"
            ),
            inputs: BaselineArtifactReportSupport.inputRecords(inputs),
            assets: assets.sorted { $0.assetId < $1.assetId }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        let output = root.appendingPathComponent(
            "docs/local/reports/stereo-compatibility-baseline-v1/payload.json"
        )
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(payload).write(to: output, options: .atomic)
        #expect(assets.count == 224)
        #expect(assets.allSatisfy { [1, 2].contains($0.evidence.sourceChannelCount) })
        #expect(assets.allSatisfy { $0.evidence.summary.allSatisfy(\.finite) })
    }

    private enum ExportError: Error {
        case unavailable(String)
    }
}
#endif
