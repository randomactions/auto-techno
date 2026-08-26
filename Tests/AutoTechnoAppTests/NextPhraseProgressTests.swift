import Foundation
import Testing
@testable import AutoTechnoApp

@Suite("Next phrase preparation progress")
struct NextPhraseProgressTests {
    @Test("Preparation, repeats, rejection, and readiness remain observable")
    func lifecycleIsTruthful() {
        var progress = NextPhraseProgress.waiting

        progress = progress.preparing(targetPhraseNumber: 4)
        #expect(progress.stage == .preparing)
        #expect(progress.attemptCount == 1)
        #expect(progress.repeatCount == 0)

        progress = progress.repeated(targetPhraseNumber: 4)
        #expect(progress.stage == .preparing)
        #expect(progress.attemptCount == 1)
        #expect(progress.repeatCount == 1)
        #expect(progress.detail.contains("REPEATS 1"))

        progress = progress.rejected(
            targetPhraseNumber: 4,
            failure: NextPhraseFailure(
                stage: "input-validation",
                code: "invalid-input",
                details: ["render-start-bar"]
            )
        )
        #expect(progress.stage == .retrying)
        #expect(progress.detail.contains("PREPARATION NOT READY"))
        #expect(progress.detail.contains("INPUT: RENDER START BAR"))
        #expect(progress.lastFailure?.details == ["render-start-bar"])

        progress = progress.preparing(targetPhraseNumber: 4)
        #expect(progress.attemptCount == 2)
        #expect(progress.repeatCount == 1)

        progress = progress.ready(targetPhraseNumber: 4)
        #expect(progress.stage == .ready)
        #expect(progress.headline == "NEXT P4 · READY")
        #expect(progress.detail.contains("QUALIFIED · CACHED"))
        #expect(progress.detail.contains("TRY 2"))
    }

    @Test("A newly targeted phrase resets old attempts and repeats")
    func newTargetResetsCounters() {
        let previousTarget = NextPhraseProgress.waiting
            .preparing(targetPhraseNumber: 4)
            .repeated(targetPhraseNumber: 4)
            .rejected(
                targetPhraseNumber: 4,
                failure: NextPhraseFailure(
                    stage: "initial-render",
                    code: "audio-preflight-unavailable"
                )
            )
        let previous = previousTarget.preparing(targetPhraseNumber: 5)

        #expect(previous.targetPhraseNumber == 5)
        #expect(previous.attemptCount == 1)
        #expect(previous.repeatCount == 0)
        #expect(previous.lastFailure == nil)
    }

    @Test("Inspector exposes accessible next phrase telemetry")
    func inspectorWiringIsPresent() throws {
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
        let inspector = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AutoTechnoApp/LiveRenderInspectorView.swift"
            ),
            encoding: .utf8
        )

        #expect(contentView.contains("nextPhraseProgress: engine.nextPhraseProgress"))
        #expect(inspector.contains("next-phrase-progress"))
        #expect(inspector.contains("Next phrase preparation"))

        let engine = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AutoTechnoApp/TechnoEngine.swift"
            ),
            encoding: .utf8
        )
        #expect(engine.contains("category: \"successor-preparation\""))
        #expect(engine.contains("Successor failed phrase="))
        #expect(engine.contains("Successor recovered phrase="))
    }
}
