#if canImport(CryptoKit)
@testable import AutoTechnoDSP
import CryptoKit
import Foundation
import Testing

@Suite("Local rhythmic baseline", .serialized)
struct RhythmicBaselineIntegrationTests {
    private struct Payload: Encodable {
        let schema = "autotechno-rhythmic-baseline-report.v1"
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
        let barDurationSeconds: Double
        let barFrameRounding: String
        let beatOrigin: String
        let eligibleSourceChannelCounts: [Int]
        let signalDomain: String
        let monoFold: String
        let onsetAnalyzerVersion: String
        let onsetAuthority: String
        let onsetActivityRelativeToSourcePeak: Double
        let onsetActivityAbsoluteFloor: Double
        let onsetEnvelopeReleaseSeconds: Double
        let onsetMergeSeconds: Double
        let scoreBindingStatus: String
        let gridStepsPerBar: Int
        let gridQuantization: String
        let microtimingUnit: String
        let exactSilenceRule: String
        let restDenominator: String
        let interOnsetPolicy: String
        let metricalDisplacementDefinition: String
        let adjacentStrongRestDefinition: String
        let maximumComparisonLagBars: Int
        let comparisonOrder: String
        let mutationDistanceDefinition: String
        let gridSimilarityDefinition: String
        let rotationSearch: String
        let comparisonAvailabilityPolicy: String
        let finalPartialBarPolicy: String
        let aggregation: String
        let interpretation: String
    }

    private struct Asset: Encodable {
        let assetId: String
        let entryId: String
        let checkpoint: String
        let continuationClass: String
        let phraseIndex: Int
        let startBar: Int
        let phraseKind: String
        let planFingerprint: String
        let pcmSha256: String
        let wavPath: String
        let evidence: PCMRhythmicBaselineEvidence
    }

    @Test("Export exact whole-mix rhythmic evidence")
    func export() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_RHYTHMIC_BASELINE"
        ] == "1" else { return }
        let root = BaselineArtifactReportSupport.repositoryRoot
        let corpusData = try Data(contentsOf: root.appendingPathComponent(
            "docs/BASELINE_CORPUS.json"
        ))
        let inputs = try BaselineArtifactReportSupport.load(root: root)
        let entries = Dictionary(
            uniqueKeysWithValues: inputs.whole.entries.map { ($0.id, $0) }
        )
        let assets = try inputs.wholeSources.map { source -> Asset in
            let channels = try BaselineArtifactReportSupport.loadWAV(
                source,
                root: root
            )
            let evidence = try #require(
                PCMRhythmicBaselineAnalyzer.analyze(
                    channels: channels,
                    sampleRate: Double(source.sampleRate)
                )
            )
            let entry = try #require(entries[source.entryId])
            return Asset(
                assetId: source.assetId,
                entryId: source.entryId,
                checkpoint: entry.checkpoint,
                continuationClass: entry.continuationClass,
                phraseIndex: entry.phraseIndex,
                startBar: entry.startBar,
                phraseKind: entry.phraseKind,
                planFingerprint: entry.planFingerprint,
                pcmSha256: source.pcmSha256,
                wavPath: source.wavPath,
                evidence: evidence
            )
        }
        let wholeInput = try #require(
            BaselineArtifactReportSupport.inputRecords(inputs).first
        )
        let payload = Payload(
            analyzerVersion: PCMRhythmicBaselineAnalyzer.analyzerVersion,
            corpusSha256: BaselineArtifactReportSupport.digest(corpusData),
            contractBaselineFingerprint: inputs.contractFingerprint,
            sourceFingerprint: inputs.whole.sourceFingerprint,
            gitHead: inputs.whole.gitHead,
            engineVersion: inputs.whole.engineVersion,
            policies: Policies(
                bpm: PCMRhythmicBaselineAnalyzer.bpm,
                beatsPerBar: PCMRhythmicBaselineAnalyzer.beatsPerBar,
                barDurationSeconds: 240.0 / 130.0,
                barFrameRounding: "nearest-frame",
                beatOrigin: "source-frame-zero-manifest-phrase-boundary",
                eligibleSourceChannelCounts: [1, 2],
                signalDomain: "accepted-whole-mix-only",
                monoFold: PCMRhythmicBaselineAnalyzer.monoFold,
                onsetAnalyzerVersion:
                    PCMTransientEnvelopeAnalyzer.analyzerVersion,
                onsetAuthority: PCMRhythmicBaselineAnalyzer.onsetAuthority,
                onsetActivityRelativeToSourcePeak:
                    PCMTransientEnvelopeAnalyzer.activityRelativeToSourcePeak,
                onsetActivityAbsoluteFloor:
                    PCMTransientEnvelopeAnalyzer.activityAbsoluteFloor,
                onsetEnvelopeReleaseSeconds:
                    PCMTransientEnvelopeAnalyzer.envelopeReleaseSeconds,
                onsetMergeSeconds:
                    PCMTransientDensityTracker.refractorySeconds,
                scoreBindingStatus:
                    PCMRhythmicBaselineAnalyzer.scoreBindingStatus,
                gridStepsPerBar:
                    PCMRhythmicBaselineAnalyzer.gridStepsPerBar,
                gridQuantization:
                    PCMRhythmicBaselineAnalyzer.gridQuantization,
                microtimingUnit:
                    "signed-fraction-of-one-sixteenth-relative-to-nearest-grid-line",
                exactSilenceRule:
                    PCMRhythmicBaselineAnalyzer.exactSilenceRule,
                restDenominator: "sixteen-grid-cells-per-complete-or-partial-bar",
                interOnsetPolicy:
                    "linear-within-every-bar-cyclic-only-for-complete-active-bars",
                metricalDisplacementDefinition:
                    PCMRhythmicBaselineAnalyzer.metricalDisplacementDefinition,
                adjacentStrongRestDefinition:
                    PCMRhythmicBaselineAnalyzer.adjacentStrongRestDefinition,
                maximumComparisonLagBars:
                    PCMRhythmicBaselineAnalyzer.maximumComparisonLagBars,
                comparisonOrder:
                    "current-bar-ascending-then-lag-one-through-four",
                mutationDistanceDefinition:
                    PCMRhythmicBaselineAnalyzer.mutationDistanceDefinition,
                gridSimilarityDefinition:
                    "sum-cellwise-minimum-over-sum-cellwise-maximum",
                rotationSearch:
                    "all-sixteen-forward-reference-rotations-lowest-shift-wins-tie",
                comparisonAvailabilityPolicy:
                    PCMRhythmicBaselineAnalyzer.comparisonAvailabilityPolicy,
                finalPartialBarPolicy:
                    PCMRhythmicBaselineAnalyzer.finalPartialBarPolicy,
                aggregation:
                    "arithmetic-mean-of-complete-bars-or-available-comparisons",
                interpretation:
                    "descriptive-not-ranked-not-calibrated-no-groove-quality-score"
            ),
            inputs: [wholeInput],
            assets: assets.sorted { $0.assetId < $1.assetId }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        let output = root.appendingPathComponent(
            "docs/local/reports/rhythmic-baseline-v1/payload.json"
        )
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(payload).write(to: output, options: .atomic)
        #expect(assets.count == 14)
        #expect(assets.allSatisfy { $0.evidence.summary.finite })
        #expect(assets.allSatisfy { $0.evidence.bars.allSatisfy(\.finite) })
        #expect(assets.allSatisfy {
            $0.evidence.comparisons.allSatisfy(\.finite)
        })
    }
}
#endif
