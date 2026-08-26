import AutoTechnoCore
@testable import AutoTechnoDSP
import AutoTechnoTransport
import Foundation
import Testing

@Suite("Current autonomous runtime")
struct CurrentRuntimeTests {
    @Test("MORDIO granular-memory identities advance as one exact contract")
    func mordioGranularMemoryPrimaryIdentityContract() {
        #expect(QualityQualificationContract.schemaVersion == 36)
        #expect(QualityQualificationContract.engineVersion ==
                "autotechno-canonical-engine.v35")
        #expect(AutonomousCandidateEvaluationVector.schemaVersion == 33)
        #expect(ProfessionalQualityObservation.schemaVersion == 14)
        #expect(ProfessionalQualityCalibrationProfile.schemaVersion == 14)
        #expect(ProfessionalQualityCalibrationProfile.profileVersion ==
                "autotechno-professional-quality-profile.v17")
        #expect(ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier ==
                "autotechno-candidate-evaluator.primary-calibrated.v17")
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v17")
        #expect(ProfessionalQualityAdversarialSuiteReport.schemaVersion == 15)
        #expect(ProfessionalQualityAdversarialSuiteReport.suiteVersion ==
                "autotechno-professional-quality-adversarial.v15")
        #expect(ProfessionalQualityHoldoutQualification.schemaVersion == 13)
        #expect(ProfessionalQualityHoldoutQualification.qualificationVersion ==
                "autotechno-professional-quality-holdout.v13")
        #expect(CanonicalJourneyQualificationReport.currentEvidenceScope ==
                "primary-structural-bs1770-signal-role-upper-modal-tail-reveal-harmonic-tail-swell-pad-rhythm-amplitude-gate-foundation-rhythm-foundation-pocket-climax-hang-harmonic-disclosure-kick-source-dynamics-granular-memory-live-commit.v18")
        #expect(AutonomousCandidateEvaluationTransaction.schemaVersion == 4)
        #expect(AutonomousPreparedCommitProvenance.schemaVersion == 2)
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 19)
        #expect(ProfessionalEvidenceReportBank.evidenceVersion ==
                "autotechno-professional-evidence.v19")
        #expect(ProfessionalQualityPrimaryArtifacts.profileResource.hasSuffix("-v17"))
        #expect(ProfessionalQualityPrimaryArtifacts.adversarialResource
            .hasSuffix("-v17"))
        #expect(ProfessionalQualityPrimaryArtifacts.holdoutResource.hasSuffix("-v17"))
    }

    @Test("Only bundled v17 resources remain")
    func primaryResourcesAreV17Only() {
        let resourceDirectory = repositoryRoot
            .appendingPathComponent("Sources/AutoTechnoDSP/Resources")
        for stem in ["profile", "adversarial-suite", "holdout"] {
            let prefix = "professional-quality-primary-\(stem)"
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v1.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v2.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v3.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v4.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v5.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v6.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v7.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v8.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v9.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v10.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v11.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v12.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v13.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v14.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v15.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v16.json").path))
            #expect(FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v17.json").path))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v1"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v2"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v3"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v4"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v5"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v6"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v7"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v8"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v9"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v10"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v11"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v12"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v13"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v14"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v15"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v16"))
            #expect(ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v17"))
        }
        #expect(throws: Never.self) {
            _ = try ProfessionalQualityPrimaryArtifacts.load()
        }
    }

    @Test("The shipped evaluator and live controller form one exact path")
    func primaryEvaluatorAndLiveControllerAreCanonical() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()

        #expect(artifacts.evaluator.evaluatorVersion ==
                ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier)
        #expect(LiveMasterHeadroomController.version ==
                "autotechno-live-master-headroom-controller.v2")
        #expect(LiveMasterHeadroomController.minimumTrimDB == -3)
        #expect(LiveMasterHeadroomController.maximumTrimDB == 0)
        #expect(LiveMasterHeadroomController.attackStepDB == 0.25)
        #expect(LiveMasterHeadroomController.recoveryStepDB == 0.125)
        #expect(LiveMasterHeadroomController.cleanWindowsForRecovery == 2)
    }
    @Test("The director owns the fixed tempo and default seed")
    func fixedSessionIdentity() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()

        #expect(AutonomousSessionDirector.bpm == 130)
        #expect(state.rootSeed == AutonomousSessionDirector.defaultSeed)
        #expect(director.plan(from: state).scene.bpm == AutonomousSessionDirector.bpm)
    }

    @Test("Scene DNA and synth planning are deterministic", arguments: [UInt64(42), 48_291, 90_909])
    func currentPlanningIsDeterministic(seed: UInt64) {
        let director = AutonomousSessionDirector(rootSeed: seed)
        let first = director.plan(from: director.initialState())
        let second = director.plan(from: director.initialState())
        let firstSynth = SynthPerformancePlan(
            scene: first.scene, dna: first.dna, kind: first.kind,
            resolvedBars: first.resolvedBars
        )
        let secondSynth = SynthPerformancePlan(
            scene: second.scene, dna: second.dna, kind: second.kind,
            resolvedBars: second.resolvedBars
        )

        #expect(first == second)
        #expect(first.scene.musicalIntent == second.scene.musicalIntent)
        #expect(first.dna == second.dna)
        #expect(firstSynth == secondSynth)
        #expect(firstSynth.bars.count == first.resolvedBars.count)
    }

    @Test("The current phrase renderer replays from continuation state")
    func rendererContinuationReplay() {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let phrase = director.plan(from: director.initialState())
        let graph = DSPGraphGenerator.safePlan(sessionSeed: 42)
        var renderA = RenderState()
        var renderB = RenderState()
        var graphA = GeneratedDSPContinuationState()
        var graphB = GeneratedDSPContinuationState()

        let first = AutonomousPhraseRenderer.render(
            plan: phrase, graph: graph, sampleRate: 8_000,
            state: &renderA, graphState: &graphA
        )
        let second = AutonomousPhraseRenderer.render(
            plan: phrase, graph: graph, sampleRate: 8_000,
            state: &renderB, graphState: &graphB
        )
        let report = AudioQualityReport(blocks: first, sampleRate: 8_000)

        #expect(first == second)
        #expect(renderA == renderB)
        #expect(graphA == graphB)
        #expect(report.finite)
        #expect(report.truePeakEstimate <= 0.95)
        #expect(abs(report.dcOffset) < 0.05)
        #expect(report.lowStereoCorrelation > 0.94)
        #expect(report.maxBoundaryDelta < 0.65)

        let source = first[0]
        let nonFiniteLeft: [Float] = [0]
        let nonFiniteRight: [Float] = [0, .nan]
        let nonFiniteFingerprint = ExactPCMFingerprint.stereo(
            left: nonFiniteLeft,
            right: nonFiniteRight
        )
        let asymmetricNonFinite = RenderBlock(
            bar: source.bar,
            section: source.section,
            left: nonFiniteLeft,
            right: nonFiniteRight,
            events: source.events,
            modulation: source.modulation,
            busStates: source.busStates,
            masking: source.masking,
            effects: source.effects,
            kickMix: source.kickMix,
            kickRenderPassesMatch: source.kickRenderPassesMatch,
            stemObservations: source.stemObservations,
            automaticMix: source.automaticMix,
            stemReconstruction: source.stemReconstruction,
            protectedFoundationSampleHash: source.protectedFoundationSampleHash,
            percussionSampleHash: source.percussionSampleHash,
            protectedRhythmSampleHash: source.protectedRhythmSampleHash,
            dryModalPercussionSampleHash:
                source.dryModalPercussionSampleHash,
            modalPercussionRenderEvidence:
                source.modalPercussionRenderEvidence,
            modalPercussionRenderPassesMatch:
                source.modalPercussionRenderPassesMatch,
            modalPercussionFoundationRoutingValid:
                source.modalPercussionFoundationRoutingValid,
            groovePulseRenderEvidence: source.groovePulseRenderEvidence,
            instrumentRenderEvidence: source.instrumentRenderEvidence,
            percussionEchoTextureRenderEvidence:
                source.percussionEchoTextureRenderEvidence,
            percussionEchoTextureRenderPassesMatch:
                source.percussionEchoTextureRenderPassesMatch,
            pulseEchoReturnDriveRenderEvidence:
                source.pulseEchoReturnDriveRenderEvidence,
            liveMasterTrimRenderEvidence: LiveMasterTrimRenderEvidence(
                requestedTrimDB: 0,
                appliedTrimDB: 0,
                appliedGain: 1,
                preTrimStereoSampleHash: nonFiniteFingerprint,
                postTrimStereoSampleHash: nonFiniteFingerprint,
                preTrimNonzeroSampleCount: 1,
                postTrimNonzeroSampleCount: 1,
                exactScaleMatches: false
            ),
            upperNoteRenderEvidence: source.upperNoteRenderEvidence,
            upperTimingRenderEvidence: source.upperTimingRenderEvidence,
            graphInputRemainderTimbreEvidence:
                source.graphInputRemainderTimbreEvidence,
            postGraphRemainderTimbreEvidence:
                source.postGraphRemainderTimbreEvidence,
            resolvedPerformance: source.resolvedPerformance,
            sceneDNA: source.sceneDNA,
            synthWorld: source.synthWorld,
            synthPerformance: source.synthPerformance
        )
        #expect(!AudioQualityReport(
            blocks: [asymmetricNonFinite],
            sampleRate: 8_000
        ).finite)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("Shared platform transport rejects cross-session stale work")
    func platformTransportPreparation() {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState()
        let request = PhrasePreparationRequest(
            key: PhrasePreparationKey(
                sessionSeed: state.rootSeed &+ 1,
                phraseIndex: state.phraseIndex,
                sampleRate: 8_000,
                channelCount:
                    QualityQualificationContract.requiredRouteChannelCount,
                routeRecovery: false,
                qualityRevision: state.quality.revision,
                qualityPolicyVersion: state.quality.policyVersion,
                qualityControllerFingerprint: nil,
                routeGeneration: 0,
                incomingLiveMasterRevision:
                    state.liveMasterHeadroom.revision,
                incomingLiveMasterStateFingerprint:
                    state.liveMasterHeadroom.fingerprint,
                pendingLiveMasterProposalFingerprint: nil,
                liveEarliestEligibleFutureSample: nil,
                liveTargetStartSample: nil
            ),
            sourceState: state,
            incomingLongHorizonState: nil,
            incomingRenderState: RenderState(),
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            pendingLiveMasterBinding: nil
        )

        let first = AutonomousPerformancePreparer.prepare(
            request: request,
            director: director,
            artifacts: nil,
            longHorizonArtifacts: nil
        )
        let second = AutonomousPerformancePreparer.prepare(
            request: request,
            director: director,
            artifacts: nil,
            longHorizonArtifacts: nil
        )

        #expect(first == nil)
        #expect(second == nil)
    }
}

@Suite("Repository surface")
struct RepositorySurfaceTests {
    @Test("Only the shipped executable product remains")
    func packageHasOneExecutableProduct() throws {
        let package = try String(contentsOf: repositoryRoot.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(package.components(separatedBy: ".executable(").count - 1 == 1)
        #expect(!package.contains(".library("))
        #expect(!package.contains("AutoTechnoReference"))
        #expect(!package.contains("AutoTechnoLeapReference"))
        #expect(!package.contains("AutoTechnoSynthReference"))
    }

    @Test("Active source and normative prose contain no retired runtime surface")
    func activeSourceHasNoRetiredSurface() throws {
        let sources = repositoryRoot.appendingPathComponent("Sources")
        let retiredSymbols = [
            "V2", "SceneRenderer", "ReferenceMetrics", "AuthoredSynthVoice",
            "DramaticJourneyPlan", "PerformancePlan", "ArrangementPlan",
            "TransitionPlan", "TechnoPattern", "TasteProfile", "JukeboxPlan",
            "AutonomousPhraseCandidates",
            "ProfessionalQualityPairedCandidateEvaluator",
            "ProfessionalQualityPairedArtifacts",
            "ProfessionalQualityDevelopmentPolicy",
            "ProfessionalQualityFrozenArtifacts",
            "usedAlternate", "usedFallback", "usedHomeTimbreFallback",
            "legacySchemaVersion", "legacySuiteVersion",
            "legacyProfileVersion", "legacyEvidenceVersion", "isLegacy",
        ]
        let retiredPhrases = [
            "conservative candidate", "nonconservative candidate",
            "conservative score", "alternate candidate", "fallback phrase",
            "development policy", "frozen policy", "usedalternate",
            "usedfallback", "private static func tom", "paired selection",
            "paired-selection", "alternate evaluator", "secondary evaluator",
            "long-horizon-professional-profile-v1",
            "long-horizon-adversarial-suite-v1",
            "long-horizon-holdout-v1",
            "callback analyzer", "master boost", "user-selectable feedback",
        ]
        let retiredProseSymbols = [
            "ProfessionalQualityPairedCandidateEvaluator",
            "ProfessionalQualityDevelopmentPolicy",
            "ProfessionalQualityFrozenArtifacts",
            "usedAlternate", "usedFallback",
        ]
        let enumerator = try #require(FileManager.default.enumerator(
            at: sources,
            includingPropertiesForKeys: [.isRegularFileKey]
        ))
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for name in retiredSymbols {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: name))\\b"
                #expect(
                    contents.range(of: pattern, options: .regularExpression) == nil,
                    "\(name) remains in \(file.lastPathComponent)"
                )
            }
            let normalized = contents.lowercased()
            for phrase in retiredPhrases {
                #expect(
                    !normalized.contains(phrase),
                    "\(phrase) remains in \(file.lastPathComponent)"
                )
            }
        }

        var proseFiles = [repositoryRoot.appendingPathComponent("README.md")]
        let docs = repositoryRoot.appendingPathComponent("docs")
        let docsEnumerator = try #require(FileManager.default.enumerator(
            at: docs,
            includingPropertiesForKeys: [.isRegularFileKey]
        ))
        for case let file as URL in docsEnumerator where file.pathExtension == "md" {
            let relativePath = file.path.replacingOccurrences(
                of: docs.path + "/", with: ""
            )
            guard !relativePath.hasPrefix("history/"),
                  !relativePath.hasPrefix("superpowers/specs/"),
                  !relativePath.hasPrefix("superpowers/plans/") else { continue }
            proseFiles.append(file)
        }
        for file in proseFiles {
            let normalized = try String(contentsOf: file, encoding: .utf8)
                .lowercased()
            for retired in retiredProseSymbols + retiredPhrases {
                #expect(
                    !normalized.contains(retired.lowercased()),
                    "\(retired) remains in \(file.lastPathComponent)"
                )
            }
        }
    }

    @Test("Active documentation exposes one canonical live-feedback path")
    func canonicalLiveFeedbackDocumentationIsCurrent() throws {
        let liveFeedbackURL = repositoryRoot.appendingPathComponent(
            "docs/LIVE_FEEDBACK.md"
        )
        #expect(FileManager.default.fileExists(atPath: liveFeedbackURL.path))
        guard FileManager.default.fileExists(atPath: liveFeedbackURL.path) else {
            return
        }

        let liveFeedback = try String(
            contentsOf: liveFeedbackURL,
            encoding: .utf8
        )
        for required in [
            "# Canonical Live Feedback",
            "## Ownership",
            "## Realtime callback boundary",
            "256",
            "1,024",
            "first exact three-second window",
            "BS.1770-5",
            "Annex 2",
            "-3...0 dB",
            "0.25 dB",
            "0.125 dB",
            "pending",
            "committed",
            "one feedback-driven invalidation",
            "one feedback-driven invalidation per authenticated scheduled occurrence",
            "accepted PCM hold",
            "occurrence epoch",
            "Late evidence alone does not latch the hold",
            "Route and timeline resets preserve a latched hold",
            "cannot authorize another correction while recovery",
            "preserve-course successor",
            "live corrections remain quarantined until advance",
            "packet count and first/last packet sequence",
            "Different valid packetization metadata changes the evidence and proposal fingerprints",
            "## Route, transport, and shutdown lifecycle",
            "## Deterministic replay",
            "## Qualification boundaries",
        ] {
            #expect(liveFeedback.contains(required),
                    "Live-feedback contract omits \(required)")
        }

        for document in [
            "docs/LIVE_FEEDBACK.md",
            "docs/AUTONOMOUS_RUNTIME_PROVENANCE.md",
            "docs/AUTONOMOUS_RUNTIME_VALIDATION.md",
            "docs/ROADMAP.md",
            "docs/history/VALIDATION_SNAPSHOTS.md",
        ] {
            let rawContents = try String(
                contentsOf: repositoryRoot.appendingPathComponent(document),
                encoding: .utf8
            ).lowercased()
            let contents = rawContents
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            #expect(contents.contains("authenticated scheduled occurrence"),
                    "\(document) omits occurrence-scoped invalidation")
            #expect(contents.contains("late evidence alone"),
                    "\(document) omits late-evidence hold isolation")
            #expect(contents.contains("route and timeline resets"),
                    "\(document) omits hold-preserving route reset")
            #expect(
                contents.contains("newer authenticated occurrence") ||
                    contents.contains("preserve-course"),
                "\(document) omits authenticated recovery"
            )
            #expect(contents.contains("complete session reset"),
                    "\(document) omits explicit hold reset")
            #expect(contents.contains("shutdown"),
                    "\(document) omits shutdown hold reset")
            #expect(contents.contains("packet count"),
                    "\(document) omits packetized replay identity")
            #expect(contents.contains("first/last packet sequence"),
                    "\(document) omits packet sequence replay identity")
            #expect(
                contents.contains("alternate valid packetization")
                    || contents.contains("valid alternate packetization")
                    || contents.contains("different valid packetization metadata"),
                "\(document) omits alternate-packetization equivalence"
            )
            #expect(
                contents.contains("evidence/proposal fingerprints")
                    || contents.contains("evidence and proposal fingerprints"),
                "\(document) omits packetization-dependent fingerprints"
            )
            #expect(!contents.contains("source phrase may invalidate"),
                    "\(document) retains phrase-scoped invalidation")
            #expect(!contents.contains("source phrase can invalidate"),
                    "\(document) retains phrase-scoped invalidation")
            #expect(!contents.contains("per source phrase"),
                    "\(document) retains phrase-scoped invalidation")
            #expect(!contents.contains("route/session lifecycle reset"),
                    "\(document) incorrectly clears hold on route reset")
            #expect(!contents.contains("route reset clears"),
                    "\(document) incorrectly clears hold on route reset")
            #expect(!contents.contains("route reset releases"),
                    "\(document) incorrectly releases hold on route reset")
            #expect(!contents.contains("route and timeline resets clear"),
                    "\(document) incorrectly clears hold on route reset")
            #expect(!contents.contains("route and timeline resets release"),
                    "\(document) incorrectly releases hold on route reset")
            #expect(!contents.contains("different packet chunking is allowed"),
                    "\(document) weakens exact packetized replay identity")
        }

        let roadmap = try String(
            contentsOf: repositoryRoot.appendingPathComponent("docs/ROADMAP.md"),
            encoding: .utf8
        )
        #expect(roadmap.contains("34-case v15 adversarial suite"))
        #expect(!roadmap.contains("fourteen-case adversarial suite"))

        for document in [
            "docs/PRODUCT.md",
            "docs/SOUND_QUALITY.md",
        ] {
            let rawContents = try String(
                contentsOf: repositoryRoot.appendingPathComponent(document),
                encoding: .utf8
            ).lowercased()
            let contents = rawContents
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            #expect(
                contents.contains(
                    "late evidence alone is ignored or deferred when its exact target is no longer unscheduled"
                ),
                "\(document) omits late-evidence target expiry"
            )
            #expect(
                contents.contains(
                    "only an already-authorized correction that is rejected, unavailable, or misses its first eligible boundary enters the accepted-pcm hold"
                ),
                "\(document) omits authorized-correction hold entry"
            )
            #expect(!contents.contains("failure repeats accepted immutable pcm"),
                    "\(document) overstates hold entry for generic failure")
            #expect(!contents.contains(
                "missed deadlines repeat already accepted immutable pcm"
            ), "\(document) overstates hold entry for generic deadlines")
            #expect(!contents.contains(
                "if analysis or preparation misses its deadline, the engine repeats accepted immutable pcm"
            ), "\(document) overstates hold entry for late analysis")
        }

        let activeDocuments = try activeDocumentationFiles()
        let combined = try activeDocuments.map {
            try String(contentsOf: $0, encoding: .utf8)
        }.joined(separator: "\n").lowercased()

        for required in [
            "autotechno-canonical-engine.v35",
            "quality-contract schema 36",
            "candidate-vector schema 33",
            "candidate-transaction schema 4",
            "professional evidence v19",
            "profile v17",
            "evaluator v17",
            "live feedback",
            "physical-output soak",
        ] {
            #expect(combined.contains(required),
                    "Active documentation omits \(required)")
        }

        for forbidden in [
            "hybrid live feedback is not implemented",
            "hybrid live feedback remains target architecture",
            "future hybrid-feedback implementation",
            "future runtime may copy",
            "current app does not copy callback pcm",
            "paired selection",
            "paired-selection",
            "paired comparator",
            "alternate evaluator",
            "secondary evaluator",
            "profile-v2",
            "adversarial-suite-v2",
            "holdout-v2",
            "callback analyzer",
            "master boost",
            "user-selectable feedback",
        ] {
            #expect(!combined.contains(forbidden),
                    "Active documentation retains \(forbidden)")
        }

        for document in [
            "README.md",
            "docs/PRODUCT.md",
            "docs/SOUND_QUALITY.md",
            "docs/AUTONOMOUS_RUNTIME_PROVENANCE.md",
            "docs/AUTONOMOUS_RUNTIME_VALIDATION.md",
            "docs/ROADMAP.md",
        ] {
            let contents = try String(
                contentsOf: repositoryRoot.appendingPathComponent(document),
                encoding: .utf8
            )
            #expect(contents.contains("LIVE_FEEDBACK.md"),
                    "\(document) does not link the canonical contract")
        }
    }

    @Test("Candidate state fingerprints use an explicit typed streaming format")
    func candidateFingerprintsAvoidReflectionAndWholeStateData() throws {
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AutoTechnoDSP/AutonomousTypedFingerprint.swift"
            ),
            encoding: .utf8
        )
        for forbidden in [
            "Mirror(", "String(describing:", "String(reflecting:",
            "JSONEncoder", "PropertyListEncoder", "Data(",
        ] {
            #expect(!source.contains(forbidden), "Typed fingerprints contain \(forbidden)")
        }
        #expect(source.contains("struct StreamingFNV1a"))
        #expect(!source.contains("public struct StreamingFNV1a"))
        #expect(source.contains("let keys = value.keys.sorted()"))
    }

    @Test("Durable sound concepts remain separate from replaceable DSP")
    func soundConceptMaturityRegisterIsExplicitAndLinked() throws {
        let maturity = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "docs/SOUND_CONCEPT_MATURITY.md"
            ),
            encoding: .utf8
        )
        let roadmap = try String(
            contentsOf: repositoryRoot.appendingPathComponent("docs/ROADMAP.md"),
            encoding: .utf8
        )

        for required in [
            "## Maturity contract",
            "## Current concept register",
            "## Revisit triggers",
            "Durable intention",
            "Current realization",
            "Truth boundary",
            "Later serious DSP direction",
            "call, delayed response, and turnaround",
            "larger temporal scale",
            "higher-resolution MSEG",
            "canonical director/score/renderer path",
        ] {
            #expect(maturity.contains(required), "Maturity register omits \(required)")
        }
        #expect(roadmap.contains("SOUND_CONCEPT_MATURITY.md"))
    }

    @Test("Windows audio completion remains fixed atomic work")
    func windowsCompletionCallbackIsolation() throws {
        let sourceURL = repositoryRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("AutoTechnoWindowsPlatform")
            .appendingPathComponent("AutoTechnoWindowsPlatform.c")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let start = try #require(source.range(of: "static void CALLBACK at_wave_out_callback"))
        let end = try #require(source.range(
            of: "static void at_remove_audio_node",
            range: start.upperBound..<source.endIndex
        ))
        let callback = String(source[start.lowerBound..<end.lowerBound])

        #expect(callback.contains("InterlockedExchange"))
        #expect(callback.contains("InterlockedAdd64"))
        #expect(callback.contains("InterlockedDecrement"))
        for forbidden in [
            "malloc(", "calloc(", "free(", "EnterCriticalSection",
            "WaitFor", "Sleep(", "PostMessage", "waveOutWrite", "printf(",
        ] {
            #expect(!callback.contains(forbidden), "Callback contains forbidden work: \(forbidden)")
        }
    }

    @Test("Both desktop hosts invoke the shared preparation owner")
    func desktopHostsUseSharedPreparation() throws {
        let sources = repositoryRoot.appendingPathComponent("Sources")
        let macHost = try String(
            contentsOf: sources
                .appendingPathComponent("AutoTechnoApp")
                .appendingPathComponent("TechnoEngine.swift"),
            encoding: .utf8
        )
        let windowsHost = try String(
            contentsOf: sources
                .appendingPathComponent("AutoTechnoWindows")
                .appendingPathComponent("main.swift"),
            encoding: .utf8
        )
        for host in [macHost, windowsHost] {
            #expect(host.contains("AutonomousPerformancePreparer.prepare("))
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func activeDocumentationFiles() throws -> [URL] {
        var files = [repositoryRoot.appendingPathComponent("README.md")]
        let docs = repositoryRoot.appendingPathComponent("docs")
        let enumerator = try #require(FileManager.default.enumerator(
            at: docs,
            includingPropertiesForKeys: [.isRegularFileKey]
        ))
        for case let file as URL in enumerator where file.pathExtension == "md" {
            let relativePath = file.path.replacingOccurrences(
                of: docs.path + "/", with: ""
            )
            guard !relativePath.hasPrefix("history/"),
                  !relativePath.hasPrefix("superpowers/specs/"),
                  !relativePath.hasPrefix("superpowers/plans/") else { continue }
            files.append(file)
        }
        return files
    }
}
