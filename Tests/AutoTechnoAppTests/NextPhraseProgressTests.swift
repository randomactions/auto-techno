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

        progress = progress.repeated(targetPhraseNumber: 4)
            .settingHoldEvolution(.pattern("loop 1 bar whole mix carousel"))
        #expect(progress.repeatCount == 2)
        #expect(progress.detail.contains("HOLD LOOP 1 BAR WHOLE MIX CAROUSEL"))
        #expect(progress.accessibilityValue.contains(
            "HOLD LOOP 1 BAR WHOLE MIX CAROUSEL"
        ))

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
        #expect(progress.repeatCount == 2)

        progress = progress.ready(targetPhraseNumber: 4)
        #expect(progress.stage == .ready)
        #expect(progress.headline == "NEXT P4 · READY")
        #expect(progress.detail.contains("QUALIFIED · CACHED"))
        #expect(progress.detail.contains("TRY 2"))
    }

    @Test("Exact fallback is explicit when no hold pattern is available")
    func exactFallbackIsExplicit() {
        let progress = NextPhraseProgress.waiting
            .preparing(targetPhraseNumber: 4)
            .repeated(targetPhraseNumber: 4)
            .repeated(targetPhraseNumber: 4)
            .settingHoldEvolution(.exactFallback)

        #expect(progress.detail.contains("HOLD EXACT"))
        #expect(progress.accessibilityValue.contains("HOLD EXACT"))
    }

    @Test("Looper family is named explicitly in the inspector")
    func looperFamilyIsExplicit() {
        let progress = NextPhraseProgress.waiting
            .preparing(targetPhraseNumber: 4)
            .repeated(targetPhraseNumber: 4)
            .repeated(targetPhraseNumber: 4)
            .repeated(targetPhraseNumber: 4)
            .settingHoldEvolution(.pattern(
                "loop 1 8 1 16 1 32 percussion cascade"
            ))

        #expect(progress.detail.contains(
            "HOLD LOOP 1 8 1 16 1 32 PERCUSSION CASCADE"
        ))
        #expect(progress.accessibilityValue.contains(
            "HOLD LOOP 1 8 1 16 1 32 PERCUSSION CASCADE"
        ))
    }

    @Test("Non-retryable preparation failure remains explicitly blocked")
    func nonRetryableFailureIsBlocked() {
        let failure = NextPhraseFailure(
            stage: "commit",
            code: "quality-rejected"
        )
        let progress = NextPhraseProgress.waiting
            .preparing(targetPhraseNumber: 9)
            .blocked(targetPhraseNumber: 9, failure: failure)
            .repeated(targetPhraseNumber: 9)

        #expect(progress.stage == .blocked)
        #expect(progress.headline == "NEXT P9 · BLOCKED")
        #expect(progress.detail.contains("PREPARATION BLOCKED"))
        #expect(progress.detail.contains("COMMIT: QUALITY REJECTED"))
        #expect(progress.repeatCount == 1)
    }

    @Test("Initial preparation failure is explicitly distinguished")
    func initialFailureIsExplicit() {
        let failure = NextPhraseFailure(
            stage: "commit",
            code: "quality-rejected"
        )
        var progress = NextPhraseProgress.waiting
            .preparingInitial(targetPhraseNumber: 1)

        progress = progress.rejectedInitial(
            targetPhraseNumber: 1,
            failure: failure
        )
        #expect(progress.stage == .retrying)
        #expect(progress.isInitialTarget)
        #expect(progress.headline == "FIRST P1 · RETRYING")
        #expect(progress.detail.contains("COMMIT: QUALITY REJECTED"))
        #expect(progress.attemptCount == 1)

        progress = progress.preparingInitial(targetPhraseNumber: 1)
        #expect(progress.attemptCount == 2)

        progress = progress.blockedInitial(
            targetPhraseNumber: 1,
            failure: failure
        )

        #expect(progress.stage == .blocked)
        #expect(progress.isInitialTarget)
        #expect(progress.headline == "FIRST P1 · BLOCKED")
        #expect(progress.detail.contains("COMMIT: QUALITY REJECTED"))
        #expect(progress.attemptCount == 2)
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
        #expect(engine.contains("Initial failed phrase="))
        #expect(engine.contains("Initial recovered phrase="))
    }

    @Test("Retryable recovery remains persistent without owning user transport")
    func recoveryDoesNotPauseOrStartANewSet() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let engine = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AutoTechnoApp/TechnoEngine.swift"
            ),
            encoding: .utf8
        )
        let recoveryStart = try #require(
            engine.range(of: "private func markNextPhraseRejected")
        )
        let recoveryEnd = try #require(
            engine.range(
                of: "private func trimPreparedCache",
                range: recoveryStart.upperBound..<engine.endIndex
            )
        )
        let recovery = engine[recoveryStart.lowerBound..<recoveryEnd.lowerBound]

        #expect(recovery.contains("continueSerially"))
        #expect(recovery.contains("beginningNextWave"))
        #expect(recovery.contains("if canRetry { prepare() }"))
        #expect(!recovery.contains("player.pause"))
        #expect(!recovery.contains("newSet"))
    }
}
