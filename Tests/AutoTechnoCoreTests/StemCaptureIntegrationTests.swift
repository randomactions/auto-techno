#if canImport(CryptoKit)
import AutoTechnoCore
@testable import AutoTechnoDSP
@testable import AutoTechnoTransport
import CryptoKit
import Foundation
import Testing

@Suite("Exact local role-stem captures", .serialized)
struct StemCaptureIntegrationTests {
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

    private struct WholeMixManifest: Decodable {
        struct Entry: Decodable {
            let id: String
            let pcmSha256: String
            let frameCount: Int
        }
        let entries: [Entry]
    }

    private struct Manifest: Encodable {
        let schema = "autotechno-role-stem-manifest.v1"
        let manifestVersion = 1
        let corpusSha256: String
        let wholeMixManifestSha256: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let nonlinearExceptions: [NonlinearException]
        let entries: [Entry]
    }

    private struct NonlinearException: Encodable {
        let id: String
        let stage: String
        let reason: String
        let residualSignal: String?
    }

    private struct Entry: Encodable {
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
        let reconstruction: Reconstruction
        let files: [StemFile]
    }

    private struct Reconstruction: Encodable {
        let protectedFoundationMaximumError: Double
        let dryCenterMaximumError: Double
        let dryUpperMaximumError: Double
        let protectedPassMaximumError: Double
        let preClimaxMaximumError: Double
        let finalMixMaximumError: Double
        let tolerance: Double
    }

    private struct StemFile: Encodable {
        let signal: String
        let classification: String
        let channelCount: Int
        let sampleRate: Int
        let frameCount: Int
        let pcmSha256: String
        let wavPath: String
        let wavSha256: String
    }

    private struct Signal {
        let id: String
        let classification: String
        let channels: Int
        let left: [Float]
        let right: [Float]?
    }

    @MainActor
    @Test("Capture every corpus identity through selected shared preparation")
    func captureAll() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_STEM_CAPTURE"
        ] == "1" else { return }
        let root = repositoryRoot
        let corpusURL = root.appendingPathComponent("docs/BASELINE_CORPUS.json")
        let corpusData = try Data(contentsOf: corpusURL)
        let corpus = try JSONDecoder().decode(Corpus.self, from: corpusData)
        let baseline = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root.appendingPathComponent(
                "docs/ROADMAP_EXECUTION_BASELINE.json"
            ))
        ) as? [String: Any]
        let wholeMixURL = root.appendingPathComponent(
            "docs/local/reports/baseline-corpus-v1/manifest.json"
        )
        let wholeMixData = try Data(contentsOf: wholeMixURL)
        let wholeMix = try JSONDecoder().decode(
            WholeMixManifest.self,
            from: wholeMixData
        )
        let wholeEntries = Dictionary(
            uniqueKeysWithValues: wholeMix.entries.map { ($0.id, $0) }
        )
        let output = root.appendingPathComponent(
            "docs/local/audio/baseline-stems-v1",
            isDirectory: true
        )
        let report = root.appendingPathComponent(
            "docs/local/reports/baseline-stems-v1",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: output,
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
                entries.append(try capture(
                    fixture,
                    route: route,
                    limit: corpus.checkpointPolicy.maximumPhrases,
                    primary: primary,
                    longHorizon: longHorizon,
                    wholeMix: try #require(
                        wholeEntries[fixture.id + "--" + route.id]
                    ),
                    output: output
                ))
            }
        }
        let manifest = Manifest(
            corpusSha256: digest(corpusData),
            wholeMixManifestSha256: digest(wholeMixData),
            contractBaselineFingerprint: try #require(
                baseline?["snapshotFingerprint"] as? String
            ),
            sourceFingerprint: try sourceFingerprint(root),
            gitHead: try gitHead(root),
            engineVersion: QualityQualificationContract.engineVersion,
            nonlinearExceptions: [
                NonlinearException(
                    id: "voice-shared-processing",
                    stage: "voice-renderer",
                    reason: "ducking, delay, chorus, FDN, glue, and master safety share state across dry roles; sourceLeft/sourceRight are reference stages rather than additive role stems",
                    residualSignal: nil
                ),
                NonlinearException(
                    id: "modal-post-master-insertion",
                    stage: "protected-modal-foundation",
                    reason: "the protected modal foundation bypasses the shared center compressor and is inserted through its own bounded post-master path",
                    residualSignal: nil
                ),
                NonlinearException(
                    id: "outer-output-safety",
                    stage: "protected-plus-processed-upper",
                    reason: "the bounded outputSafety curve is nonlinear when the recombined sample approaches its limit",
                    residualSignal: "output-safety-residual"
                ),
                NonlinearException(
                    id: "terminal-processing",
                    stage: "climax-and-live-master",
                    reason: "climax hang and accepted live-master trim operate on the recombined stereo signal",
                    residualSignal: "terminal-processing-residual"
                ),
            ],
            entries: entries.sorted { $0.id < $1.id }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes,
        ]
        try encoder.encode(manifest).write(
            to: report.appendingPathComponent("manifest.json"),
            options: .atomic
        )
        #expect(entries.count == corpus.cases.count * corpus.routes.count)
    }

    private func capture(
        _ fixture: Corpus.Case,
        route: Corpus.Route,
        limit: Int,
        primary: ProfessionalQualityPrimaryArtifacts,
        longHorizon: LongHorizonProfessionalPolicyArtifacts,
        wholeMix: WholeMixManifest.Entry,
        output: URL
    ) throws -> Entry {
        let director = AutonomousSessionDirector(rootSeed: fixture.rootSeed)
        var state = director.initialState()
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        var previousGraph: DSPGraphPlan?
        var horizon: LongHorizonFutureAdaptationState?
        var previousChapter: InterlockChapter?
        for _ in 0..<limit {
            let request = PhrasePreparationRequest(
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
                    incomingLiveMasterRevision:
                        state.liveMasterHeadroom.revision,
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
            let prepared = try #require(
                AutonomousPerformancePreparer.prepare(
                    request: request,
                    director: director,
                    artifacts: primary,
                    longHorizonArtifacts: longHorizon,
                    diagnosticRoleStemCapture: true
                )
            )
            let plan = prepared.prepared.plan
            let chapters = plan.resolvedBars.map(\.interlockChapter)
            let changed = zip(chapters, chapters.dropFirst()).contains {
                $0.0 != $0.1
            } || (previousChapter.flatMap { previous in
                chapters.first.map { $0 != previous }
            } ?? false)
            if CanonicalJourneyCheckpoint.applicable(
                phraseIndex: plan.phraseIndex,
                phraseKind: plan.kind,
                chapterChanged: changed
            ).contains(fixture.checkpoint) {
                return try write(
                    prepared,
                    fixture: fixture,
                    route: route,
                    wholeMix: wholeMix,
                    output: output
                )
            }
            previousChapter = chapters.last ?? previousChapter
            state = state.advance(
                using: plan,
                quality: prepared.prepared.qualityContinuationState,
                liveMasterHeadroom:
                    prepared.prepared.liveMasterHeadroomContinuationState,
                longHorizonDecision: prepared.longHorizonDecision
            )
            renderState = prepared.prepared.endingRenderState
            graphState = prepared.prepared.endingGraphState
            previousGraph = prepared.prepared.graph
            horizon = prepared.outgoingLongHorizonState
        }
        throw CaptureError.missingCheckpoint
    }

    private func write(
        _ product: PreparedPerformancePhrase,
        fixture: Corpus.Case,
        route: Corpus.Route,
        wholeMix: WholeMixManifest.Entry,
        output: URL
    ) throws -> Entry {
        let blocks = product.prepared.blocks
        let captures = product.prepared.diagnosticRoleStemCaptures
        guard blocks.count == captures.count, !blocks.isEmpty else {
            throw CaptureError.invalidCapture
        }
        let frameCount = blocks.reduce(0) { $0 + $1.left.count }
        guard frameCount == wholeMix.frameCount,
              captures.allSatisfy({
                  $0.frameCountsAreAligned && $0.samplesAreFinite
              }) else {
            throw CaptureError.invalidCapture
        }
        var wholePCM = Data()
        wholePCM.reserveCapacity(frameCount * 8)
        for block in blocks {
            appendStereo(left: block.left, right: block.right, to: &wholePCM)
        }
        guard digest(wholePCM) == wholeMix.pcmSha256 else {
            throw CaptureError.wholeMixMismatch
        }

        let signals = makeSignals(captures)
        let id = fixture.id + "--" + route.id
        var files: [StemFile] = []
        for signal in signals {
            let pcm = pcmData(signal)
            let wav = wave(
                pcm: pcm,
                rate: route.sampleRate,
                channels: signal.channels
            )
            let filename = id + "--" + signal.id + ".wav"
            try wav.write(
                to: output.appendingPathComponent(filename),
                options: .atomic
            )
            files.append(StemFile(
                signal: signal.id,
                classification: signal.classification,
                channelCount: signal.channels,
                sampleRate: route.sampleRate,
                frameCount: signal.left.count,
                pcmSha256: digest(pcm),
                wavPath: "docs/local/audio/baseline-stems-v1/" + filename,
                wavSha256: digest(wav)
            ))
        }
        let reconstruction = reconstructionEvidence(
            captures: captures,
            blocks: blocks
        )
        guard reconstruction.protectedFoundationMaximumError < 0.000_001,
              reconstruction.dryCenterMaximumError < 0.000_001,
              reconstruction.dryUpperMaximumError < 0.000_001,
              reconstruction.protectedPassMaximumError == 0,
              reconstruction.preClimaxMaximumError < 0.000_001,
              reconstruction.finalMixMaximumError < 0.000_001 else {
            let maxima: String = [
                "protectedFoundation=\(reconstruction.protectedFoundationMaximumError)",
                "dryCenter=\(reconstruction.dryCenterMaximumError)",
                "dryUpper=\(reconstruction.dryUpperMaximumError)",
                "protectedPass=\(reconstruction.protectedPassMaximumError)",
                "preClimax=\(reconstruction.preClimaxMaximumError)",
                "finalMix=\(reconstruction.finalMixMaximumError)",
            ].joined(separator: ", ")
            Issue.record("stem reconstruction maxima: \(maxima)")
            throw CaptureError.reconstruction
        }
        return Entry(
            id: id,
            caseId: fixture.id,
            routeId: route.id,
            rootSeed: fixture.rootSeed,
            checkpoint: fixture.checkpoint.rawValue,
            continuationClass: fixture.continuationClass,
            phraseIndex: product.prepared.plan.phraseIndex,
            startBar: product.prepared.plan.startBar,
            phraseKind: product.prepared.plan.kind.rawValue,
            stateFingerprint: AutonomousCandidateFingerprint.sessionState(
                product.request.sourceState
            ),
            planFingerprint: AutonomousCandidateFingerprint.plan(
                product.prepared.plan
            ),
            replayFingerprint: product.request.replayIdentity.fingerprint,
            policyVersion: product.prepared.qualityDecision.policyVersion,
            qualityOutcome: product.prepared.qualityDecision.outcome.rawValue,
            sampleRate: route.sampleRate,
            wholeMixChannelCount: route.channelCount,
            frameCount: frameCount,
            wholeMixPcmSha256: wholeMix.pcmSha256,
            reconstruction: reconstruction,
            files: files.sorted { $0.signal < $1.signal }
        )
    }

    private func makeSignals(
        _ captures: [AutonomousBarRoleStemCapture]
    ) -> [Signal] {
        func mono(
            _ id: String,
            _ classification: String,
            _ samples: (AutonomousBarRoleStemCapture) -> [Float]
        ) -> Signal {
            Signal(
                id: id,
                classification: classification,
                channels: 1,
                left: captures.flatMap(samples),
                right: nil
            )
        }
        func stereo(
            _ id: String,
            _ classification: String,
            _ samples: (AutonomousBarRoleStemCapture) -> ([Float], [Float])
        ) -> Signal {
            var left: [Float] = []
            var right: [Float] = []
            for capture in captures {
                let pair = samples(capture)
                left.append(contentsOf: pair.0)
                right.append(contentsOf: pair.1)
            }
            return Signal(
                id: id,
                classification: classification,
                channels: 2,
                left: left,
                right: right
            )
        }
        return [
            mono("kick", "linear-role") { $0.full.kick },
            mono("foundation", "linear-role") { $0.full.foundation },
            mono("modal-foundation", "protected-subrole") {
                $0.full.modalFoundation
            },
            mono("percussion", "linear-role") { $0.full.percussion },
            mono("upper-tonal", "linear-role") { $0.full.upperTonal },
            mono("atmosphere", "linear-role") { $0.full.atmosphere },
            mono("protected-foundation", "protected-variant") {
                $0.protectedRhythm.protectedFoundation
            },
            mono("dry-center-reference", "reconstruction-reference") {
                $0.full.dryCenterReference
            },
            mono("dry-upper-reference", "reconstruction-reference") {
                $0.full.dryUpperReference
            },
            stereo("protected-rhythm", "protected-variant") {
                ($0.protectedRhythm.sourceLeft, $0.protectedRhythm.sourceRight)
            },
            stereo("graph-input", "processed-stage") {
                ($0.graphInputLeft, $0.graphInputRight)
            },
            stereo("processed-upper", "processed-stage") {
                ($0.processedUpperLeft, $0.processedUpperRight)
            },
            stereo("pre-climax-mix", "processed-stage") {
                ($0.preClimaxMixLeft, $0.preClimaxMixRight)
            },
            stereo("output-safety-residual", "nonlinear-residual") {
                ($0.outputSafetyResidualLeft, $0.outputSafetyResidualRight)
            },
            stereo("terminal-processing-residual", "nonlinear-residual") {
                (
                    $0.terminalProcessingResidualLeft,
                    $0.terminalProcessingResidualRight
                )
            },
        ]
    }

    private func reconstructionEvidence(
        captures: [AutonomousBarRoleStemCapture],
        blocks: [RenderBlock]
    ) -> Reconstruction {
        var protectedFoundation = 0.0
        var dryCenter = 0.0
        var dryUpper = 0.0
        var protectedPass = 0.0
        var preClimax = 0.0
        var finalMix = 0.0
        for (capture, block) in zip(captures, blocks) {
            for frame in 0..<capture.frameCount {
                protectedFoundation = max(protectedFoundation, Double(abs(
                    capture.full.protectedFoundation[frame] -
                        (capture.full.kick[frame] +
                         capture.full.foundation[frame])
                )))
                dryCenter = max(dryCenter, Double(abs(
                    capture.full.dryCenterReference[frame] -
                        (capture.full.protectedFoundation[frame] +
                         capture.full.percussion[frame] -
                         capture.full.modalFoundation[frame])
                )))
                dryUpper = max(dryUpper, Double(abs(
                    capture.full.dryUpperReference[frame] -
                        (capture.full.upperTonal[frame] +
                         capture.full.atmosphere[frame])
                )))
                protectedPass = max(
                    protectedPass,
                    Double(abs(capture.full.kick[frame] -
                               capture.protectedRhythm.kick[frame])),
                    Double(abs(capture.full.foundation[frame] -
                               capture.protectedRhythm.foundation[frame])),
                    Double(abs(capture.full.modalFoundation[frame] -
                               capture.protectedRhythm.modalFoundation[frame])),
                    Double(abs(capture.full.percussion[frame] -
                               capture.protectedRhythm.percussion[frame])),
                    Double(abs(capture.full.protectedFoundation[frame] -
                               capture.protectedRhythm.protectedFoundation[frame]))
                )
                preClimax = max(
                    preClimax,
                    Double(abs(
                        capture.preClimaxMixLeft[frame] -
                            (capture.protectedRhythm.sourceLeft[frame] +
                             capture.processedUpperLeft[frame] +
                             capture.outputSafetyResidualLeft[frame])
                    )),
                    Double(abs(
                        capture.preClimaxMixRight[frame] -
                            (capture.protectedRhythm.sourceRight[frame] +
                             capture.processedUpperRight[frame] +
                             capture.outputSafetyResidualRight[frame])
                    ))
                )
                finalMix = max(
                    finalMix,
                    Double(abs(
                        block.left[frame] -
                            (capture.preClimaxMixLeft[frame] +
                             capture.terminalProcessingResidualLeft[frame])
                    )),
                    Double(abs(
                        block.right[frame] -
                            (capture.preClimaxMixRight[frame] +
                             capture.terminalProcessingResidualRight[frame])
                    ))
                )
            }
        }
        return Reconstruction(
            protectedFoundationMaximumError: protectedFoundation,
            dryCenterMaximumError: dryCenter,
            dryUpperMaximumError: dryUpper,
            protectedPassMaximumError: protectedPass,
            preClimaxMaximumError: preClimax,
            finalMixMaximumError: finalMix,
            tolerance: 0.000_001
        )
    }

    private func pcmData(_ signal: Signal) -> Data {
        var data = Data()
        data.reserveCapacity(signal.left.count * signal.channels * 4)
        if let right = signal.right {
            appendStereo(left: signal.left, right: right, to: &data)
        } else {
            for sample in signal.left { append(sample, to: &data) }
        }
        return data
    }

    private func appendStereo(
        left: [Float],
        right: [Float],
        to data: inout Data
    ) {
        for index in left.indices {
            append(left[index], to: &data)
            append(right[index], to: &data)
        }
    }

    private func append(_ sample: Float, to data: inout Data) {
        var bits = sample.bitPattern.littleEndian
        withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
    }

    private func wave(pcm: Data, rate: Int, channels: Int) -> Data {
        let blockAlign = channels * 4
        var data = Data()
        func text(_ value: String) {
            data.append(value.data(using: .ascii)!)
        }
        func u16(_ value: UInt16) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        func u32(_ value: UInt32) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        text("RIFF")
        u32(UInt32(36 + pcm.count))
        text("WAVEfmt ")
        u32(16)
        u16(3)
        u16(UInt16(channels))
        u32(UInt32(rate))
        u32(UInt32(rate * blockAlign))
        u16(UInt16(blockAlign))
        u16(32)
        text("data")
        u32(UInt32(pcm.count))
        data.append(pcm)
        return data
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
        guard process.terminationStatus == 0 else { throw CaptureError.git }
        return String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sourceFingerprint(_ root: URL) throws -> String {
        let manager = FileManager.default
        let roots = [
            "Package.swift",
            "Sources",
            "docs/BASELINE_CORPUS.json",
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
                    (try? $0.resourceValues(forKeys: [.isRegularFileKey])
                        .isRegularFile) == true
                }.map {
                    $0.path.replacingOccurrences(
                        of: root.path + "/",
                        with: ""
                    )
                }
            } else {
                paths.append(item)
            }
        }
        var data = Data()
        for path in paths.sorted() {
            data.append(Data(path.utf8))
            data.append(0)
            data.append(try Data(contentsOf: root.appendingPathComponent(path)))
        }
        return digest(data)
    }

    private enum CaptureError: Error {
        case missingCheckpoint
        case invalidCapture
        case wholeMixMismatch
        case reconstruction
        case git
    }
}
#endif
