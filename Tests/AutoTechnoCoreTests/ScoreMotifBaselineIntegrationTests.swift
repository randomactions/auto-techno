#if canImport(CryptoKit)
import AutoTechnoCore
@testable import AutoTechnoDSP
@testable import AutoTechnoTransport
import CryptoKit
import Foundation
import Testing

@Suite("Local accepted-score motif baseline", .serialized)
struct ScoreMotifBaselineIntegrationTests {
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

    private struct WholeManifest: Decodable {
        struct Entry: Decodable {
            let id: String
            let planFingerprint: String
            let stateFingerprint: String
            let replayFingerprint: String
            let pcmSha256: String
        }
        let entries: [Entry]
    }

    private struct Payload: Encodable {
        let schema = "autotechno-score-motif-baseline-report.v1"
        let reportVersion = 1
        let analyzerVersion: String
        let scoreSchemaVersion: String
        let corpusSha256: String
        let wholeManifestSha256: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let policies: Policies
        let assets: [Asset]
    }

    private struct Policies: Encodable {
        let signalAuthority = "accepted-resolved-upper-score-not-pcm-inference"
        let eligibleRoles: [String]
        let excludedRoles = ["atmosphere", "transition"]
        let scopeOrder: [String]
        let tokenOrder =
            "onset-then-synth-role-order-then-end-pitch-duration-source-order"
        let duplicatePolicy = "retain-every-resolved-note-with-stable-ordinal"
        let pitchRepresentation =
            "midi-millinote-c2-root-plus-tonal-center-plus-rounded-log2-ratio"
        let onsetRepresentation =
            "rounded-millisteps-from-onset-step-plus-score-timing-offset"
        let durationRepresentation = "rounded-millisteps"
        let contourRepresentation = "ordered-signed-end-pitch-interval-vector"
        let densityDenominator =
            "sixteen-cells-per-role-or-forty-eight-combined-eligible-role-cells"
        let maximumComparisonLagBars: Int
        let mutationDistance =
            "levenshtein-edit-count-divided-by-longer-sequence-count"
        let rotationSearch =
            "all-sixteen-forward-reference-grid-step-rotations-lowest-shift-wins"
        let inactivePolicy =
            "absent-role-and-empty-motif-are-explicit-unavailable-comparisons"
        let aggregation = "arithmetic-mean-of-available-comparisons"
        let interpretation =
            "descriptive-not-ranked-not-calibrated-no-quality-or-future-decision"
    }

    private struct Asset: Encodable {
        let assetId: String
        let caseId: String
        let routeId: String
        let rootSeed: UInt64
        let checkpoint: String
        let continuationClass: String
        let sampleRate: Int
        let channelCount: Int
        let phraseIndex: Int
        let startBar: Int
        let phraseKind: String
        let planFingerprint: String
        let stateFingerprint: String
        let replayFingerprint: String
        let acceptedPCMSha256: String
        let input: ScoreMotifPhraseInput
        let evidence: ScoreMotifBaselineEvidence
    }

    @MainActor
    @Test("Export and bind every accepted corpus score")
    func export() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_SCORE_MOTIF_BASELINE"
        ] == "1" else { return }
        let root = repositoryRoot
        let corpusURL = root.appendingPathComponent("docs/BASELINE_CORPUS.json")
        let manifestURL = root.appendingPathComponent(
            "docs/local/reports/baseline-corpus-v1/manifest.json"
        )
        let snapshotURL = root.appendingPathComponent(
            "docs/ROADMAP_EXECUTION_BASELINE.json"
        )
        let corpusData = try Data(contentsOf: corpusURL)
        let manifestData = try Data(contentsOf: manifestURL)
        let corpus = try JSONDecoder().decode(Corpus.self, from: corpusData)
        let whole = try JSONDecoder().decode(WholeManifest.self, from: manifestData)
        let entries = Dictionary(uniqueKeysWithValues: whole.entries.map { ($0.id, $0) })
        let snapshot = try JSONSerialization.jsonObject(
            with: Data(contentsOf: snapshotURL)
        ) as? [String: Any]
        let primary = try ProfessionalQualityPrimaryArtifacts.load()
        let longHorizon = try LongHorizonProfessionalPolicyArtifacts.load()
        var assets: [Asset] = []
        for fixture in corpus.cases {
            for route in corpus.routes {
                let id = fixture.id + "--" + route.id
                let expected = try #require(entries[id])
                let product = try prepare(
                    fixture,
                    route: route,
                    limit: corpus.checkpointPolicy.maximumPhrases,
                    primary: primary,
                    longHorizon: longHorizon
                )
                let plan = product.prepared.plan
                let input = try #require(
                    ScoreMotifBaselineAnalyzer.canonicalInput(plan: plan)
                )
                let evidence: ScoreMotifBaselineEvidence
                switch ScoreMotifBaselineAnalyzer.analyze(input: input) {
                case .available(let value): evidence = value
                case .unavailable(let reason):
                    Issue.record("Score motif analysis unavailable: \(reason.rawValue)")
                    throw ExportError.unavailable
                }
                let planFingerprint = AutonomousCandidateFingerprint.plan(plan)
                let stateFingerprint = AutonomousCandidateFingerprint.sessionState(
                    product.request.sourceState
                )
                #expect(planFingerprint == expected.planFingerprint)
                #expect(stateFingerprint == expected.stateFingerprint)
                #expect(product.request.replayIdentity.fingerprint ==
                    expected.replayFingerprint)
                assets.append(Asset(
                    assetId: id,
                    caseId: fixture.id,
                    routeId: route.id,
                    rootSeed: fixture.rootSeed,
                    checkpoint: fixture.checkpoint.rawValue,
                    continuationClass: fixture.continuationClass,
                    sampleRate: route.sampleRate,
                    channelCount: route.channelCount,
                    phraseIndex: plan.phraseIndex,
                    startBar: plan.startBar,
                    phraseKind: plan.kind.rawValue,
                    planFingerprint: planFingerprint,
                    stateFingerprint: stateFingerprint,
                    replayFingerprint: product.request.replayIdentity.fingerprint,
                    acceptedPCMSha256: expected.pcmSha256,
                    input: input,
                    evidence: evidence
                ))
            }
        }
        for fixture in corpus.cases {
            let paired = assets.filter { $0.caseId == fixture.id }
            #expect(paired.count == corpus.routes.count)
            #expect(Set(paired.map(\.planFingerprint)).count == 1)
            #expect(Set(paired.map { $0.evidence.evidenceFingerprint }).count == 1)
            #expect(paired.dropFirst().allSatisfy { $0.input == paired[0].input })
        }
        let payload = Payload(
            analyzerVersion: ScoreMotifBaselineSchema.analyzerVersion,
            scoreSchemaVersion: ScoreMotifBaselineSchema.scoreSchemaVersion,
            corpusSha256: digest(corpusData),
            wholeManifestSha256: digest(manifestData),
            contractBaselineFingerprint: try #require(
                snapshot?["snapshotFingerprint"] as? String
            ),
            sourceFingerprint: try sourceFingerprint(root),
            gitHead: try gitHead(root),
            engineVersion: QualityQualificationContract.engineVersion,
            policies: Policies(
                eligibleRoles: ScoreMotifBaselineSchema.eligibleRoles,
                scopeOrder: ScoreMotifBaselineSchema.scopeOrder,
                maximumComparisonLagBars:
                    ScoreMotifBaselineSchema.maximumComparisonLagBars
            ),
            assets: assets.sorted { $0.assetId < $1.assetId }
        )
        let output = root.appendingPathComponent(
            "docs/local/reports/score-motif-baseline-v1/payload.json"
        )
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(payload).write(to: output, options: .atomic)
        #expect(assets.count == corpus.cases.count * corpus.routes.count)
    }

    @MainActor
    private func prepare(
        _ fixture: Corpus.Case,
        route: Corpus.Route,
        limit: Int,
        primary: ProfessionalQualityPrimaryArtifacts,
        longHorizon: LongHorizonProfessionalPolicyArtifacts
    ) throws -> PreparedPerformancePhrase {
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
                    incomingLiveMasterRevision: state.liveMasterHeadroom.revision,
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
            let prepared = try #require(AutonomousPerformancePreparer.prepare(
                request: request,
                director: director,
                artifacts: primary,
                longHorizonArtifacts: longHorizon
            ))
            let plan = prepared.prepared.plan
            let chapters = plan.resolvedBars.map(\.interlockChapter)
            let changed = zip(chapters, chapters.dropFirst()).contains {
                $0.0 != $0.1
            } || (previousChapter.flatMap { prior in
                chapters.first.map { $0 != prior }
            } ?? false)
            if CanonicalJourneyCheckpoint.applicable(
                phraseIndex: plan.phraseIndex,
                phraseKind: plan.kind,
                chapterChanged: changed
            ).contains(fixture.checkpoint) {
                return prepared
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
        throw ExportError.missingCheckpoint
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func gitHead(_ root: URL) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path, "rev-parse", "HEAD"]
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ExportError.git }
        return String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sourceFingerprint(_ root: URL) throws -> String {
        let manager = FileManager.default
        let roots = [
            "Package.swift", "Sources", "docs/BASELINE_CORPUS.json",
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
                    (try? $0.resourceValues(
                        forKeys: [.isRegularFileKey]
                    ).isRegularFile) == true
                }.map {
                    $0.path.replacingOccurrences(of: root.path + "/", with: "")
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

    private enum ExportError: Error {
        case unavailable
        case missingCheckpoint
        case git
    }
}
#endif
