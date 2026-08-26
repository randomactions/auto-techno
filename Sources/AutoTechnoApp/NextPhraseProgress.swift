/// Read-only presentation state for the one canonical successor-preparation
/// path. This state never participates in musical decisions or callback work.
package struct NextPhraseProgress: Equatable, Sendable {
    package enum Stage: Equatable, Sendable {
        case waiting
        case held
        case queued
        case preparing
        case ready
        case retrying
    }

    package let stage: Stage
    package let targetPhraseNumber: Int?
    package let attemptCount: Int
    package let repeatCount: Int

    package static let waiting = NextPhraseProgress(
        stage: .waiting,
        targetPhraseNumber: nil,
        attemptCount: 0,
        repeatCount: 0
    )

    package func holding(targetPhraseNumber: Int) -> Self {
        updating(stage: .held, targetPhraseNumber: targetPhraseNumber)
    }

    package func queued(targetPhraseNumber: Int) -> Self {
        updating(stage: .queued, targetPhraseNumber: targetPhraseNumber)
    }

    package func preparing(targetPhraseNumber: Int) -> Self {
        let counts = counts(for: targetPhraseNumber)
        return Self(
            stage: .preparing,
            targetPhraseNumber: targetPhraseNumber,
            attemptCount: counts.attempts + 1,
            repeatCount: counts.repeats
        )
    }

    package func ready(targetPhraseNumber: Int) -> Self {
        updating(stage: .ready, targetPhraseNumber: targetPhraseNumber)
    }

    package func rejected(targetPhraseNumber: Int) -> Self {
        updating(stage: .retrying, targetPhraseNumber: targetPhraseNumber)
    }

    package func repeated(targetPhraseNumber: Int) -> Self {
        let counts = counts(for: targetPhraseNumber)
        let retainedStage: Stage = switch stage {
        case .preparing: .preparing
        case .queued: .queued
        case .held: .held
        case .waiting, .ready, .retrying: .retrying
        }
        return Self(
            stage: retainedStage,
            targetPhraseNumber: targetPhraseNumber,
            attemptCount: counts.attempts,
            repeatCount: counts.repeats + 1
        )
    }

    package var headline: String {
        let target = targetPhraseNumber.map { "NEXT P\($0)" } ?? "NEXT PHRASE"
        return "\(target) · \(stageTitle)"
    }

    package var detail: String {
        var parts: [String] = []
        switch stage {
        case .waiting:
            parts.append("WAITING FOR CURRENT PHRASE")
        case .held:
            parts.append("BOUNDARY HOLD")
        case .queued:
            parts.append("WAITING FOR WORKER")
        case .preparing:
            parts.append("DETACHED PREPARATION")
        case .ready:
            parts.append("QUALIFIED · CACHED")
        case .retrying:
            parts.append("PREPARATION NOT READY")
        }
        if attemptCount > 0, stage != .ready || attemptCount > 1 {
            parts.append("TRY \(attemptCount)")
        }
        if repeatCount > 0 {
            parts.append("REPEATS \(repeatCount)")
        }
        return parts.joined(separator: " · ")
    }

    package var accessibilityValue: String {
        "\(headline). \(detail)."
    }

    private var stageTitle: String {
        switch stage {
        case .waiting: "WAITING"
        case .held: "HELD"
        case .queued: "QUEUED"
        case .preparing: "PREPARING"
        case .ready: "READY"
        case .retrying: "RETRYING"
        }
    }

    private func updating(
        stage: Stage,
        targetPhraseNumber: Int
    ) -> Self {
        let counts = counts(for: targetPhraseNumber)
        return Self(
            stage: stage,
            targetPhraseNumber: targetPhraseNumber,
            attemptCount: counts.attempts,
            repeatCount: counts.repeats
        )
    }

    private func counts(for targetPhraseNumber: Int) -> (
        attempts: Int,
        repeats: Int
    ) {
        guard self.targetPhraseNumber == targetPhraseNumber else {
            return (0, 0)
        }
        return (attemptCount, repeatCount)
    }
}
