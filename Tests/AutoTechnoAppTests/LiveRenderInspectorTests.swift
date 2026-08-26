import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing
@testable import AutoTechnoApp

@Suite("Read-only live render inspector", .serialized)
struct LiveRenderInspectorTests {
    @Test("Detached render metadata becomes one bounded snapshot per bar")
    func projectsPreparedBars() throws {
        let fixture = renderFixture(seed: 48_291)
        let snapshots = LiveRenderSnapshot.make(
            plan: fixture.plan,
            graph: fixture.graph,
            blocks: fixture.blocks,
            sampleRate: 8_000,
            channelCount: 2
        )

        #expect(snapshots.count == fixture.blocks.count)
        let first = try #require(snapshots.first)
        #expect(first.available)
        #expect(first.phraseNumber == fixture.plan.phraseIndex + 1)
        #expect(first.barNumber == fixture.blocks[0].performance.localBar + 1)
        #expect(first.frameCount == fixture.blocks[0].left.count)
        #expect(first.durationSeconds > 0)
        #expect(first.sampleRate == 8_000)
        #expect(first.channelCount == 2)
        #expect(first.graphNodes.count == fixture.graph.nodes.count)
        #expect(first.graphBranchCount == fixture.graph.branchCount)
        #expect(first.graphMaximumDepth == fixture.graph.maximumDepth)
        #expect(!first.voices.isEmpty)
        #expect(first.effects.count <= EffectKind.allCases.count)
        #expect(first.graphNodes.count <= DSPGraphPlan.maximumNodeCount)
        #expect(first.assignments.allSatisfy {
            (0...1).contains($0.color) &&
                (0...1).contains($0.shape) &&
                (0...1).contains($0.motion) &&
                (0...1).contains($0.space)
        })
    }

    @Test("Snapshot projection is deterministic and rejects invalid routes")
    func deterministicProjectionAndRouteGuard() {
        let fixture = renderFixture(seed: 90_909)
        let first = LiveRenderSnapshot.make(
            plan: fixture.plan,
            graph: fixture.graph,
            blocks: fixture.blocks,
            sampleRate: 8_000,
            channelCount: 2
        )
        let replay = LiveRenderSnapshot.make(
            plan: fixture.plan,
            graph: fixture.graph,
            blocks: fixture.blocks,
            sampleRate: 8_000,
            channelCount: 2
        )

        #expect(first == replay)
        #expect(LiveRenderSnapshot.make(
            plan: fixture.plan,
            graph: fixture.graph,
            blocks: fixture.blocks,
            sampleRate: .nan,
            channelCount: 2
        ).isEmpty)
        #expect(LiveRenderSnapshot.make(
            plan: fixture.plan,
            graph: fixture.graph,
            blocks: fixture.blocks,
            sampleRate: 8_000,
            channelCount: 0
        ).isEmpty)
    }

    @Test("Inspector labels preserve technical word boundaries")
    func humanReadableLabels() {
        #expect(InspectorLabel.title("acidPressure") == "Acid Pressure")
        #expect(InspectorLabel.title("spatialFDN") == "Spatial FDN")
        #expect(InspectorLabel.title("granular-memory") == "Granular Memory")
        #expect(InspectorLabel.title("openHat") == "Open Hat")
    }

    @Test("The UI switch is read-only, keyboard reachable, and accessible")
    func inspectorControlIsReachable() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentView = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AutoTechnoApp/ContentView.swift"
            ),
            encoding: .utf8
        )
        let engine = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AutoTechnoApp/TechnoEngine.swift"
            ),
            encoding: .utf8
        )

        #expect(contentView.contains("view-render-inspector"))
        #expect(contentView.contains("Show live render information"))
        #expect(contentView.contains("keyboardShortcut(\"i\", modifiers: [.command])"))
        #expect(!contentView.contains("Slider("))
        #expect(!contentView.contains("Toggle("))
        #expect(engine.contains("let inspectorSnapshots = LiveRenderSnapshot.make("))
        #expect(engine.contains("Task.detached(priority: .userInitiated)"))
        #expect(engine.contains("liveRenderSnapshot = visual.inspectorSnapshot"))
    }

    private func renderFixture(
        seed: UInt64
    ) -> (plan: AutonomousPhrasePlan, graph: DSPGraphPlan, blocks: [RenderBlock]) {
        let director = AutonomousSessionDirector(rootSeed: seed)
        let plan = director.plan(from: director.initialState())
        let graph = DSPGraphGenerator.safePlan(sessionSeed: seed)
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        let blocks = AutonomousPhraseRenderer.render(
            plan: plan,
            graph: graph,
            sampleRate: 8_000,
            state: &renderState,
            graphState: &graphState
        )
        return (plan, graph, blocks)
    }
}
