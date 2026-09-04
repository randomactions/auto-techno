#if canImport(CryptoKit)
import AutoTechnoCore
@testable import AutoTechnoDSP
@testable import AutoTechnoTransport
import Foundation
import Testing

@Suite("Local kick/foundation collision baseline", .serialized)
struct KickFoundationCollisionIntegrationTests {
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

    private struct Payload: Encodable {
        let schema = "autotechno-kick-foundation-collision-report.v1"
        let reportVersion = 1
        let analyzerVersion: String
        let corpusSha256: String
        let contractBaselineFingerprint: String
        let sourceFingerprint: String
        let gitHead: String
        let engineVersion: String
        let policies: Policies
        let inputs: [BaselineReportInput]
        let entries: [Entry]
    }

    private struct Policies: Encodable {
        let bpm: Double
        let beatsPerBar: Int
        let scoreStepsPerBar: Int
        let eventWindowSteps: Int
        let eventWindowRounding: String
        let windowsPerEvent: Int
        let activityMeanSquareThreshold: Double
        let lowBand: MaskingBand
        let lowBandOverlapThreshold: Double
        let bandEnergyModel: String
        let durationModel: String
        let eventSource: String
        let confidence: String
        let relativeEnergyUnit: String
        let relativeEnergyInterpretation: String
        let phasePolicy: String
        let noKickPolicy: String
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
        let candidateEvaluationFingerprint: String
        let sampleRate: Int
        let frameCount: Int
        let kickPcmSha256: String
        let foundationPcmSha256: String
        let barCount: Int
        let barsWithoutKick: [Int]
        let evidence: PCMKickFoundationCollisionEvidence
    }

    @MainActor
    @Test("Bind every corpus kick to exact accepted role PCM")
    func export() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_KICK_FOUNDATION_COLLISION"
        ] == "1" else { return }
        let root = BaselineArtifactReportSupport.repositoryRoot
        let corpusData = try Data(contentsOf: root.appendingPathComponent(
            "docs/BASELINE_CORPUS.json"
        ))
        let corpus = try JSONDecoder().decode(Corpus.self, from: corpusData)
        let inputs = try BaselineArtifactReportSupport.load(root: root)
        let wholeEntries = Dictionary(
            uniqueKeysWithValues: inputs.whole.entries.map { ($0.id, $0) }
        )
        let stemEntries = Dictionary(
            uniqueKeysWithValues: inputs.stems.entries.map { ($0.id, $0) }
        )
        let sources = Dictionary(
            uniqueKeysWithValues: inputs.stemSources.map { ($0.assetId, $0) }
        )
        let primary = try ProfessionalQualityPrimaryArtifacts.load()
        let longHorizon = try LongHorizonProfessionalPolicyArtifacts.load()
        var entries: [Entry] = []
        for fixture in corpus.cases {
            for route in corpus.routes {
                let id = fixture.id + "--" + route.id
                let whole = try #require(wholeEntries[id])
                let stems = try #require(stemEntries[id])
                let kickSource = try #require(sources[id + "::kick"])
                let foundationSource = try #require(
                    sources[id + "::foundation"]
                )
                let product = try prepare(
                    fixture,
                    route: route,
                    limit: corpus.checkpointPolicy.maximumPhrases,
                    primary: primary,
                    longHorizon: longHorizon
                )
                entries.append(try makeEntry(
                    product,
                    fixture: fixture,
                    route: route,
                    whole: whole,
                    stems: stems,
                    kickSource: kickSource,
                    foundationSource: foundationSource,
                    root: root
                ))
            }
        }
        let payload = Payload(
            analyzerVersion:
                PCMKickFoundationCollisionAnalyzer.analyzerVersion,
            corpusSha256: BaselineArtifactReportSupport.digest(corpusData),
            contractBaselineFingerprint: inputs.contractFingerprint,
            sourceFingerprint: inputs.whole.sourceFingerprint,
            gitHead: inputs.whole.gitHead,
            engineVersion: inputs.whole.engineVersion,
            policies: Policies(
                bpm: 130,
                beatsPerBar: 4,
                scoreStepsPerBar: 16,
                eventWindowSteps: 2,
                eventWindowRounding: "nearest-frame-bar-relative",
                windowsPerEvent:
                    PCMKickFoundationCollisionAnalyzer.windowsPerEvent,
                activityMeanSquareThreshold:
                    PCMKickFoundationCollisionAnalyzer
                        .activityMeanSquareThreshold,
                lowBand: SpectrumMaskingAnalyzer.bands[0],
                lowBandOverlapThreshold:
                    PCMKickFoundationCollisionAnalyzer
                        .lowBandOverlapThreshold,
                bandEnergyModel:
                    PCMKickFoundationCollisionAnalyzer.bandEnergyModel,
                durationModel:
                    PCMKickFoundationCollisionAnalyzer.durationModel,
                eventSource:
                    PCMKickFoundationCollisionAnalyzer.eventSource,
                confidence:
                    PCMKickFoundationCollisionAnalyzer.confidence,
                relativeEnergyUnit:
                    PCMKickFoundationCollisionAnalyzer.relativeEnergyUnit,
                relativeEnergyInterpretation:
                    PCMKickFoundationCollisionAnalyzer
                        .relativeEnergyInterpretation,
                phasePolicy:
                    "per-role-energy-only-no-role-sum-cancellation-inference",
                noKickPolicy:
                    "valid-entry-with-zero-eligible-events-and-explicit-bars"
            ),
            inputs: BaselineArtifactReportSupport.inputRecords(inputs),
            entries: entries.sorted { $0.id < $1.id }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes,
        ]
        let output = root.appendingPathComponent(
            "docs/local/reports/kick-foundation-collision-v1/payload.json"
        )
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(payload).write(to: output, options: .atomic)
        #expect(entries.count == corpus.cases.count * corpus.routes.count)
        #expect(entries.allSatisfy { $0.evidence.finite })
        #expect(entries.reduce(0) { $0 + $1.evidence.events.count } > 0)
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
                    longHorizonArtifacts: longHorizon
                )
            )
            let plan = prepared.prepared.plan
            let chapters = plan.resolvedBars.map(\.interlockChapter)
            let chapterChanged = zip(chapters, chapters.dropFirst()).contains {
                $0.0 != $0.1
            } || (previousChapter.flatMap { previous in
                chapters.first.map { $0 != previous }
            } ?? false)
            if CanonicalJourneyCheckpoint.applicable(
                phraseIndex: plan.phraseIndex,
                phraseKind: plan.kind,
                chapterChanged: chapterChanged
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
        throw IntegrationError.missingCheckpoint
    }

    private func makeEntry(
        _ product: PreparedPerformancePhrase,
        fixture: Corpus.Case,
        route: Corpus.Route,
        whole: BaselineWholeManifest.Entry,
        stems: BaselineStemManifest.Entry,
        kickSource: BaselineReportAssetSource,
        foundationSource: BaselineReportAssetSource,
        root: URL
    ) throws -> Entry {
        let prepared = product.prepared
        let id = fixture.id + "--" + route.id
        let stateFingerprint = AutonomousCandidateFingerprint.sessionState(
            product.request.sourceState
        )
        let planFingerprint = AutonomousCandidateFingerprint.plan(prepared.plan)
        let frameCount = prepared.blocks.reduce(0) { $0 + $1.left.count }
        guard whole.id == id,
              stems.id == id,
              identityMatches(
                fixture: fixture,
                route: route,
                phraseIndex: prepared.plan.phraseIndex,
                startBar: prepared.plan.startBar,
                phraseKind: prepared.plan.kind.rawValue,
                stateFingerprint: stateFingerprint,
                planFingerprint: planFingerprint,
                replayFingerprint: product.request.replayIdentity.fingerprint,
                qualityPolicy: prepared.qualityDecision.policyVersion,
                qualityOutcome: prepared.qualityDecision.outcome.rawValue,
                whole: whole,
                stems: stems
              ),
              whole.frameCount == frameCount,
              stems.frameCount == frameCount,
              kickSource.frameCount == frameCount,
              foundationSource.frameCount == frameCount,
              kickSource.sampleRate == route.sampleRate,
              foundationSource.sampleRate == route.sampleRate,
              kickSource.channelCount == 1,
              foundationSource.channelCount == 1,
              prepared.plan.resolvedBars.count == prepared.blocks.count,
              prepared.selectedCandidateEvidence.kickSyntax.count ==
                prepared.blocks.count,
              prepared.selectedCandidateEvidence.foundationRhythm.count ==
                prepared.blocks.count else {
            throw IntegrationError.identityMismatch(id)
        }
        let kick = try BaselineArtifactReportSupport.loadWAV(
            kickSource,
            root: root
        )[0]
        let foundation = try BaselineArtifactReportSupport.loadWAV(
            foundationSource,
            root: root
        )[0]
        var events: [PCMKickFoundationEventInput] = []
        var barsWithoutKick: [Int] = []
        var barStartFrame = 0
        for index in prepared.blocks.indices {
            let block = prepared.blocks[index]
            let resolved = prepared.plan.resolvedBars[index]
            let kickEvidence = prepared.selectedCandidateEvidence
                .kickSyntax[index]
            let foundationEvidence = prepared.selectedCandidateEvidence
                .foundationRhythm[index]
            let kickEvents = resolved.ensemble.events.filter {
                $0.voice == .kick
            }
            let kickSteps = kickEvents.map(\.step).sorted()
            guard kickEvidence.bar == resolved.performance.bar,
                  kickEvidence.isComplete(sampleRate: Double(route.sampleRate)),
                  kickEvidence.bindingValid,
                  kickEvidence.scoreKickEventCount == kickSteps.count,
                  kickEvidence.scoreKickStepMask == stepMask(kickSteps),
                  foundationEvidence.bar == resolved.performance.bar,
                  foundationEvidence.isComplete(
                    sampleRate: Double(route.sampleRate)
                  ),
                  foundationEvidence.bindingValid,
                  block.left.count == block.right.count else {
                throw IntegrationError.eventBinding(id)
            }
            if kickEvents.isEmpty {
                barsWithoutKick.append(resolved.performance.bar)
            }
            let authoredRoles = resolved.ensemble.events.compactMap { event in
                switch event.voice {
                case .bass, .rumble, .tunedTom:
                    event.voice.rawValue
                default:
                    nil
                }
            }
            for event in kickEvents.sorted(by: { $0.step < $1.step }) {
                let onset = barStartFrame + Int((
                    Double(event.step) * Double(block.left.count) / 16.0
                ).rounded())
                let pocket = pocketInput(
                    foundationEvidence.preKickPocket,
                    kickStep: event.step,
                    barStartFrame: barStartFrame
                )
                events.append(PCMKickFoundationEventInput(
                    id: id + "--bar-\(resolved.performance.bar)-step-\(event.step)",
                    bar: resolved.performance.bar,
                    step: event.step,
                    barStartFrame: barStartFrame,
                    barFrameCount: block.left.count,
                    onsetFrame: onset,
                    authoredFoundationRolesInBar: authoredRoles,
                    pocket: pocket
                ))
            }
            barStartFrame += block.left.count
        }
        guard barStartFrame == frameCount else {
            throw IntegrationError.eventBinding(id)
        }
        guard case let .available(evidence) =
                PCMKickFoundationCollisionAnalyzer.analyze(
                    kick: kick,
                    foundation: foundation,
                    sampleRate: Double(route.sampleRate),
                    events: events
                ) else {
            throw IntegrationError.analysisUnavailable(id)
        }
        return Entry(
            id: id,
            caseId: fixture.id,
            routeId: route.id,
            rootSeed: fixture.rootSeed,
            checkpoint: fixture.checkpoint.rawValue,
            continuationClass: fixture.continuationClass,
            phraseIndex: prepared.plan.phraseIndex,
            startBar: prepared.plan.startBar,
            phraseKind: prepared.plan.kind.rawValue,
            stateFingerprint: stateFingerprint,
            planFingerprint: planFingerprint,
            replayFingerprint: product.request.replayIdentity.fingerprint,
            candidateEvaluationFingerprint:
                prepared.candidateEvaluationFingerprint,
            sampleRate: route.sampleRate,
            frameCount: frameCount,
            kickPcmSha256: kickSource.pcmSha256,
            foundationPcmSha256: foundationSource.pcmSha256,
            barCount: prepared.blocks.count,
            barsWithoutKick: barsWithoutKick,
            evidence: evidence
        )
    }

    private func identityMatches(
        fixture: Corpus.Case,
        route: Corpus.Route,
        phraseIndex: Int,
        startBar: Int,
        phraseKind: String,
        stateFingerprint: String,
        planFingerprint: String,
        replayFingerprint: String,
        qualityPolicy: String,
        qualityOutcome: String,
        whole: BaselineWholeManifest.Entry,
        stems: BaselineStemManifest.Entry
    ) -> Bool {
        let common = whole.caseId == fixture.id &&
            stems.caseId == fixture.id &&
            whole.routeId == route.id && stems.routeId == route.id &&
            whole.rootSeed == fixture.rootSeed &&
            stems.rootSeed == fixture.rootSeed &&
            whole.checkpoint == fixture.checkpoint.rawValue &&
            stems.checkpoint == fixture.checkpoint.rawValue &&
            whole.continuationClass == fixture.continuationClass &&
            stems.continuationClass == fixture.continuationClass &&
            whole.phraseIndex == phraseIndex && stems.phraseIndex == phraseIndex &&
            whole.startBar == startBar && stems.startBar == startBar &&
            whole.phraseKind == phraseKind && stems.phraseKind == phraseKind &&
            whole.stateFingerprint == stateFingerprint &&
            stems.stateFingerprint == stateFingerprint &&
            whole.planFingerprint == planFingerprint &&
            stems.planFingerprint == planFingerprint &&
            whole.replayFingerprint == replayFingerprint &&
            stems.replayFingerprint == replayFingerprint &&
            whole.policyVersion == qualityPolicy &&
            stems.policyVersion == qualityPolicy &&
            whole.qualityOutcome == qualityOutcome &&
            stems.qualityOutcome == qualityOutcome &&
            whole.sampleRate == route.sampleRate &&
            stems.sampleRate == route.sampleRate &&
            whole.channelCount == route.channelCount &&
            stems.wholeMixChannelCount == route.channelCount &&
            stems.wholeMixPcmSha256 == whole.pcmSha256
        return common
    }

    private func pocketInput(
        _ evidence: AutonomousFoundationPreKickPocketEvidence,
        kickStep: Int,
        barStartFrame: Int
    ) -> PCMKickFoundationPocketInput? {
        guard evidence.applied, evidence.kickStep == kickStep else { return nil }
        return PCMKickFoundationPocketInput(
            releaseStartFrame: barStartFrame + evidence.releaseStartFrame,
            releaseEndFrame: barStartFrame + evidence.releaseEndFrame,
            kickFrame: barStartFrame + evidence.kickFrame,
            silenceFrameCount: evidence.silenceFrameCount,
            silencePeak: evidence.silencePeak,
            silenceRMS: evidence.silenceRMS,
            applied: evidence.applied,
            finite: evidence.finite
        )
    }

    private func stepMask(_ steps: [Int]) -> UInt16 {
        steps.reduce(into: UInt16(0)) { result, step in
            if (0..<16).contains(step) {
                result |= UInt16(1) << UInt16(step)
            }
        }
    }

    private enum IntegrationError: Error {
        case missingCheckpoint
        case identityMismatch(String)
        case eventBinding(String)
        case analysisUnavailable(String)
    }
}
#endif
