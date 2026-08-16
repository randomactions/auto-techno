import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Current autonomous runtime")
struct CurrentRuntimeTests {
    @Test("Modal primary identities advance as one exact contract")
    func modalPrimaryIdentityContract() {
        #expect(QualityQualificationContract.schemaVersion == 21)
        #expect(QualityQualificationContract.engineVersion ==
                "autotechno-canonical-engine.v20")
        #expect(AutonomousCandidateEvaluationVector.schemaVersion == 19)
        #expect(ProfessionalQualityObservation.schemaVersion == 2)
        #expect(ProfessionalEvidenceReportBank.schemaVersion == 5)
        #expect(ProfessionalQualityPrimaryEvaluator.policyFamilyVersion ==
                "autotechno-quality.primary-calibrated.v2")
        #expect(ProfessionalQualityAdversarialSuiteReport.schemaVersion == 3)
        #expect(CanonicalJourneyQualificationReport.currentEvidenceScope ==
                "primary-structural-bs1770-signal-role-upper-modal-commit.v5")
        #expect(AutonomousCandidateEvaluationTransaction.schemaVersion == 3)
        #expect(ProfessionalQualityPrimaryArtifacts.profileResource.hasSuffix("-v2"))
        #expect(ProfessionalQualityPrimaryArtifacts.adversarialResource
            .hasSuffix("-v2"))
        #expect(ProfessionalQualityPrimaryArtifacts.holdoutResource.hasSuffix("-v2"))
    }

    @Test("Only v2 primary resources are present in source and bundle")
    func primaryResourcesAreV2Only() {
        let resourceDirectory = repositoryRoot
            .appendingPathComponent("Sources/AutoTechnoDSP/Resources")
        for stem in ["profile", "adversarial-suite", "holdout"] {
            let prefix = "professional-quality-primary-\(stem)"
            #expect(!FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v1.json").path))
            #expect(FileManager.default.fileExists(atPath:
                resourceDirectory.appendingPathComponent("\(prefix)-v2.json").path))
            #expect(!ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v1"))
            #expect(ProfessionalQualityPrimaryArtifacts
                .containsBundledResource(named: "\(prefix)-v2"))
        }
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
        ]
        let retiredPhrases = [
            "conservative candidate", "nonconservative candidate",
            "conservative score", "alternate candidate", "fallback phrase",
            "development policy", "frozen policy", "usedalternate",
            "usedfallback", "private static func tom",
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
}
