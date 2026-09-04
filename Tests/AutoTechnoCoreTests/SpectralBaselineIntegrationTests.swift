#if canImport(CryptoKit)
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Local PCM spectral baseline", .serialized)
struct SpectralBaselineIntegrationTests {
    private struct Payload: Encodable {
        let schema = "autotechno-spectral-baseline-report.v1"
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
        let monoFold: String
        let windowsPerSegment: Int
        let timelineCellPartition: String
        let spectrumWindowSeconds: Double
        let spectrumWindowFunction: String
        let spectrumWindowPlacement: String
        let fftPadding: String
        let bandEnergyModel: String
        let bandEnergyUnit: String
        let bandEnergyConservation: String
        let activityMeanSquareThreshold: Double
        let subBandName: String
        let minimumSubBandShare: Double
        let lowEndOccupancyDenominator: String
        let shortSegmentPolicy: String
        let decibelFloor: Double
    }

    private struct Asset: Encodable {
        let assetId: String
        let domain: String
        let entryId: String
        let signal: String
        let classification: String
        let pcmSha256: String
        let wavPath: String
        let evidence: PCMSpectralBaselineEvidence
    }

    @Test("Analyze every exact whole mix and role signal into one spectral payload")
    func export() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_SPECTRAL_BASELINE"
        ] == "1" else { return }
        let root = BaselineArtifactReportSupport.repositoryRoot
        let inputs = try BaselineArtifactReportSupport.load(root: root)
        var assets: [Asset] = []
        assets.reserveCapacity(inputs.sources.count)
        for source in inputs.sources {
            let channels = try BaselineArtifactReportSupport.loadWAV(
                source,
                root: root
            )
            let framesPerBar = Int(
                (Double(source.sampleRate) * 240.0 / 130.0).rounded()
            )
            let evidence = try #require(PCMSpectralBaselineAnalyzer.analyze(
                channels: channels,
                sampleRate: Double(source.sampleRate),
                segmentFrameCount: framesPerBar
            ))
            try #require(evidence.frameCount == source.frameCount)
            try #require(evidence.sourceChannelCount == source.channelCount)
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
            analyzerVersion: PCMSpectralBaselineAnalyzer.analyzerVersion,
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
                monoFold: PCMSpectralBaselineAnalyzer.monoFold,
                windowsPerSegment: PCMSpectralBaselineAnalyzer.windowsPerSegment,
                timelineCellPartition: "contiguous-equal-count-causal-cells",
                spectrumWindowSeconds:
                    StreamingPerceptualEvidenceAnalyzer.targetWindowSeconds,
                spectrumWindowFunction: "symmetric-Hann",
                spectrumWindowPlacement:
                    PCMSpectralBaselineAnalyzer.spectrumWindowPlacement,
                fftPadding: "next-power-of-two-zero-padding",
                bandEnergyModel: PCMSpectralBaselineAnalyzer.bandEnergyModel,
                bandEnergyUnit: "mean-square-amplitude-squared",
                bandEnergyConservation: "not-claimed",
                activityMeanSquareThreshold:
                    PCMSpectralBaselineAnalyzer.activeMeanSquareThreshold,
                subBandName: "sub",
                minimumSubBandShare:
                    PCMSpectralBaselineAnalyzer.minimumSubBandShare,
                lowEndOccupancyDenominator: "source-active-window-count",
                shortSegmentPolicy: "unavailable-below-one-spectrum-window",
                decibelFloor: PCMSpectralBaselineAnalyzer.decibelFloor
            ),
            inputs: BaselineArtifactReportSupport.inputRecords(inputs),
            assets: assets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        let output = root.appendingPathComponent(
            "docs/local/reports/spectral-baseline-v1/payload.json"
        )
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(payload).write(to: output, options: .atomic)
        #expect(assets.count == 224)
        #expect(assets.allSatisfy { $0.evidence.summary.finite })
    }
}
#endif
