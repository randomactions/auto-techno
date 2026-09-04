#if canImport(CryptoKit)
@testable import AutoTechnoDSP
import CryptoKit
import Foundation
import Testing

@Suite("Local transient/envelope baseline", .serialized)
struct TransientEnvelopeBaselineIntegrationTests {
    private struct Payload: Encodable {
        let schema = "autotechno-transient-envelope-baseline-report.v1"
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
        let legacyDetectionThreshold: Double
        let legacyRefractorySeconds: Double
        let legacyReferenceSampleRate: Double
        let legacyReferenceEnvelopeCoefficient: Double
        let onsetAuthority: String
        let activityRelativeToSourcePeak: Double
        let activityAbsoluteFloor: Double
        let envelopeAttack: String
        let envelopeReleaseSeconds: Double
        let onsetMergeSeconds: Double
        let peakSearchSeconds: Double
        let eventWindowSeconds: Double
        let eventWindowBoundary: String
        let attackLowerFraction: Double
        let attackUpperFraction: Double
        let attackShapeMetric: String
        let decayActivityFraction: Double
        let decayLandmarkFraction: Double
        let decayOccupancyDenominator: String
        let crestUnit: String
        let segmentEventAttribution: String
        let noEventPolicy: String
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
        let evidence: PCMTransientEnvelopeEvidence
    }

    @Test("Export exact whole/role transient and envelope evidence")
    func export() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_TRANSIENT_ENVELOPE_BASELINE"
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
            let evidence = try #require(
                PCMTransientEnvelopeAnalyzer.analyze(
                    channels: channels,
                    sampleRate: Double(source.sampleRate),
                    segmentFrameCount: segmentFrames
                )
            )
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
            analyzerVersion: PCMTransientEnvelopeAnalyzer.analyzerVersion,
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
                monoFold: PCMTransientEnvelopeAnalyzer.monoFold,
                legacyDetectionThreshold:
                    PCMTransientDensityTracker.detectionThreshold,
                legacyRefractorySeconds:
                    PCMTransientDensityTracker.refractorySeconds,
                legacyReferenceSampleRate:
                    PCMTransientDensityTracker.referenceSampleRate,
                legacyReferenceEnvelopeCoefficient:
                    PCMTransientDensityTracker.referenceEnvelopeCoefficient,
                onsetAuthority: PCMTransientEnvelopeAnalyzer.onsetAuthority,
                activityRelativeToSourcePeak:
                    PCMTransientEnvelopeAnalyzer.activityRelativeToSourcePeak,
                activityAbsoluteFloor:
                    PCMTransientEnvelopeAnalyzer.activityAbsoluteFloor,
                envelopeAttack: "instantaneous-rectified-peak",
                envelopeReleaseSeconds:
                    PCMTransientEnvelopeAnalyzer.envelopeReleaseSeconds,
                onsetMergeSeconds:
                    PCMTransientDensityTracker.refractorySeconds,
                peakSearchSeconds:
                    PCMTransientEnvelopeAnalyzer.peakSearchSeconds,
                eventWindowSeconds:
                    PCMTransientEnvelopeAnalyzer.eventWindowSeconds,
                eventWindowBoundary:
                    "earliest-of-next-onset-fixed-window-source-end",
                attackLowerFraction:
                    PCMTransientEnvelopeAnalyzer.attackLowerFraction,
                attackUpperFraction:
                    PCMTransientEnvelopeAnalyzer.attackUpperFraction,
                attackShapeMetric:
                    "mean-peak-normalized-envelope-between-landmarks-inclusive",
                decayActivityFraction:
                    PCMTransientEnvelopeAnalyzer.decayActivityFraction,
                decayLandmarkFraction:
                    PCMTransientEnvelopeAnalyzer.decayLandmarkFraction,
                decayOccupancyDenominator:
                    "peak-through-analysis-end-frame-count",
                crestUnit: "linear-peak-over-rms-arithmetic-fold",
                segmentEventAttribution: "onset-frame-in-segment",
                noEventPolicy: PCMTransientEnvelopeAnalyzer.noEventPolicy,
                interpretation: "descriptive-not-ranked-not-calibrated"
            ),
            inputs: BaselineArtifactReportSupport.inputRecords(inputs),
            assets: assets.sorted { $0.assetId < $1.assetId }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        let output = root.appendingPathComponent(
            "docs/local/reports/transient-envelope-baseline-v1/payload.json"
        )
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(payload).write(to: output, options: .atomic)
        #expect(assets.count == 224)
        #expect(assets.allSatisfy { $0.evidence.summary.finite })
        #expect(assets.allSatisfy { $0.evidence.events.allSatisfy(\.finite) })
    }
}
#endif
