import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Current autonomous runtime")
struct CurrentRuntimeTests {
    @Test("The director owns the fixed tempo and default seed")
    func fixedSessionIdentity() {
        let director = AutonomousSessionDirector()
        let state = director.initialState()

        #expect(AutonomousSessionDirector.bpm == 130)
        #expect(state.rootSeed == AutonomousSessionDirector.defaultSeed)
        #expect(director.candidates(from: state).primary.scene.bpm == AutonomousSessionDirector.bpm)
    }

    @Test("Scene DNA and synth planning are deterministic", arguments: [UInt64(42), 48_291, 90_909])
    func currentPlanningIsDeterministic(seed: UInt64) {
        let director = AutonomousSessionDirector(rootSeed: seed)
        let first = director.candidates(from: director.initialState()).primary
        let second = director.candidates(from: director.initialState()).primary
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
        let phrase = director.candidates(from: director.initialState()).primary
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
        let asymmetricNonFinite = RenderBlock(
            bar: source.bar,
            section: source.section,
            left: [0],
            right: [0, .nan],
            events: source.events,
            modulation: source.modulation,
            busStates: source.busStates,
            masking: source.masking,
            effects: source.effects,
            kickMix: source.kickMix,
            stemObservations: source.stemObservations,
            automaticMix: source.automaticMix,
            stemReconstruction: source.stemReconstruction,
            protectedFoundationSampleHash: source.protectedFoundationSampleHash,
            percussionSampleHash: source.percussionSampleHash,
            protectedRhythmSampleHash: source.protectedRhythmSampleHash,
            groovePulseRenderEvidence: source.groovePulseRenderEvidence,
            upperNoteRenderEvidence: source.upperNoteRenderEvidence,
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

    @Test("Active Swift source contains no retired runtime surface")
    func activeSourceHasNoRetiredSurface() throws {
        let sources = repositoryRoot.appendingPathComponent("Sources")
        let retired = [
            "V2", "SceneRenderer", "ReferenceMetrics", "AuthoredSynthVoice",
            "DramaticJourneyPlan", "PerformancePlan", "ArrangementPlan",
            "TransitionPlan", "TechnoPattern", "TasteProfile", "JukeboxPlan",
        ]
        let enumerator = try #require(FileManager.default.enumerator(
            at: sources,
            includingPropertiesForKeys: [.isRegularFileKey]
        ))
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for name in retired {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: name))\\b"
                #expect(
                    contents.range(of: pattern, options: .regularExpression) == nil,
                    "\(name) remains in \(file.lastPathComponent)"
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
        #expect(source.contains("private struct StreamingFNV1a"))
        #expect(source.contains("let keys = value.keys.sorted()"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
