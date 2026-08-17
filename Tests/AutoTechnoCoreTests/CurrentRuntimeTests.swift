import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Current autonomous runtime")
struct CurrentRuntimeTests {
    @Test("Live headroom primary identities advance as one exact contract")
    func liveHeadroomPrimaryIdentityContract() {
        #expect(QualityQualificationContract.schemaVersion == 22)
        #expect(QualityQualificationContract.engineVersion ==
                "autotechno-canonical-engine.v21")
        #expect(AutonomousCandidateEvaluationVector.schemaVersion == 20)
        #expect(ProfessionalQualityObservation.schemaVersion == 3)
        #expect(ProfessionalQualityCalibrationProfile.schemaVersion == 3)
        #expect(ProfessionalQualityCalibrationProfile.profileVersion ==
                "autotechno-professional-quality-profile.v3")
        #expect(ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier ==
                "autotechno-candidate-evaluator.primary-calibrated.v3")
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v3")
        #expect(ProfessionalQualityAdversarialSuiteReport.schemaVersion == 4)
        #expect(ProfessionalQualityAdversarialSuiteReport.suiteVersion ==
                "autotechno-professional-quality-adversarial.v4")
        #expect(ProfessionalQualityHoldoutQualification.schemaVersion == 2)
        #expect(ProfessionalQualityHoldoutQualification.qualificationVersion ==
                "autotechno-professional-quality-holdout.v2")
        #expect(CanonicalJourneyQualificationReport.currentEvidenceScope ==
                "primary-structural-bs1770-signal-role-upper-modal-live-commit.v6")
        #expect(AutonomousCandidateEvaluationTransaction.schemaVersion == 4)
        #expect(AutonomousPreparedCommitProvenance.schemaVersion == 2)
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 6)
        #expect(ProfessionalEvidenceReportBank.evidenceVersion ==
                "autotechno-professional-evidence.v6")
        #expect(ProfessionalQualityPrimaryArtifacts.profileResource.hasSuffix("-v3"))
        #expect(ProfessionalQualityPrimaryArtifacts.adversarialResource
            .hasSuffix("-v3"))
        #expect(ProfessionalQualityPrimaryArtifacts.holdoutResource.hasSuffix("-v3"))
    }

    @Test("Only bundled v3 resources remain")
    func primaryResourcesAreV3Only() {
        let resourceDirectory = repositoryRoot
            .appendingPathComponent("Sources/AutoTechnoDSP/Resources")
        for stem in ["profile", "adversarial-suite", "holdout"] {
            let prefix = "professional-quality-primary-\(stem)"
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v1.json").path))
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v2.json").path))
            #expect(FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v3.json").path))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v1"))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v2"))
            #expect(ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v3"))
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
                "autotechno-live-master-headroom-controller.v1")
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
            "profile-v2", "adversarial-suite-v2", "holdout-v2",
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
            "does not itself clear the hold",
            "complete session reset or shutdown",
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
            #expect(contents.contains("newer authenticated occurrence"),
                    "\(document) omits authenticated recovery")
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
        #expect(roadmap.contains("23-case v4 adversarial suite"))
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
            "autotechno-canonical-engine.v21",
            "quality-contract schema 22",
            "candidate-vector schema 20",
            "candidate-transaction schema 4",
            "professional evidence v6",
            "profile v3",
            "evaluator v3",
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
