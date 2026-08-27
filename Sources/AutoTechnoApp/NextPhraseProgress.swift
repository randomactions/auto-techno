/// Read-only presentation state for the one canonical successor-preparation
/// path. This state never participates in musical decisions or callback work.
package struct NextPhraseFailure: Error, Equatable, Sendable {
    package let stage: String
    package let code: String
    package let details: [String]

    package init(stage: String, code: String, details: [String] = []) {
        self.stage = stage
        self.code = code
        var seen: Set<String> = []
        self.details = details.filter { seen.insert($0).inserted }
            .prefix(24)
            .map { $0 }
    }

    package var conciseLabel: String {
        let stageLabel = switch stage {
        case "request-validation": "REQUEST"
        case "input-validation": "INPUT"
        case "continuation": "STATE"
        case "initial-render": "RENDER"
        case "correction-render": "CORRECTION"
        case "transaction": "EVIDENCE"
        case "finalization", "commit": "COMMIT"
        case "presentation": "INSPECTOR"
        default: "PREPARATION"
        }
        let diagnostic = code == "invalid-input" ? details.first ?? code : code
        let codeLabel = diagnostic
            .replacingOccurrences(of: "-", with: " ")
            .uppercased()
        return "\(stageLabel): \(codeLabel)"
    }

    package var logDetails: String {
        details.isEmpty ? "none" : details.joined(separator: ",")
    }
}

package struct NextPhraseProgress: Equatable, Sendable {
    package enum Stage: Equatable, Sendable {
        case waiting
        case held
        case queued
        case preparing
        case ready
        case retrying
        case blocked
    }

    package let stage: Stage
    package let targetPhraseNumber: Int?
    package let isInitialTarget: Bool
    package let attemptCount: Int
    package let repeatCount: Int
    package let lastFailure: NextPhraseFailure?

    package static let waiting = NextPhraseProgress(
        stage: .waiting,
        targetPhraseNumber: nil,
        isInitialTarget: false,
        attemptCount: 0,
        repeatCount: 0,
        lastFailure: nil
    )

    package func holding(targetPhraseNumber: Int) -> Self {
        updating(stage: .held, targetPhraseNumber: targetPhraseNumber)
    }

    package func queued(targetPhraseNumber: Int) -> Self {
        updating(stage: .queued, targetPhraseNumber: targetPhraseNumber)
    }

    package func preparing(targetPhraseNumber: Int) -> Self {
        let counts = counts(for: targetPhraseNumber, isInitial: false)
        return Self(
            stage: .preparing,
            targetPhraseNumber: targetPhraseNumber,
            isInitialTarget: false,
            attemptCount: counts.attempts + 1,
            repeatCount: counts.repeats,
            lastFailure: counts.failure
        )
    }

    package func ready(targetPhraseNumber: Int) -> Self {
        updating(stage: .ready, targetPhraseNumber: targetPhraseNumber)
    }

    package func rejected(
        targetPhraseNumber: Int,
        failure: NextPhraseFailure
    ) -> Self {
        let counts = counts(for: targetPhraseNumber)
        return Self(
            stage: .retrying,
            targetPhraseNumber: targetPhraseNumber,
            isInitialTarget: false,
            attemptCount: counts.attempts,
            repeatCount: counts.repeats,
            lastFailure: failure
        )
    }

    package func blocked(
        targetPhraseNumber: Int,
        failure: NextPhraseFailure
    ) -> Self {
        let counts = counts(for: targetPhraseNumber)
        return Self(
            stage: .blocked,
            targetPhraseNumber: targetPhraseNumber,
            isInitialTarget: false,
            attemptCount: counts.attempts,
            repeatCount: counts.repeats,
            lastFailure: failure
        )
    }

    package func repeated(targetPhraseNumber: Int) -> Self {
        let counts = counts(
            for: targetPhraseNumber,
            isInitial: isInitialTarget
        )
        let retainedStage: Stage = switch stage {
        case .preparing: .preparing
        case .queued: .queued
        case .held: .held
        case .waiting, .ready, .retrying: .retrying
        case .blocked: .blocked
        }
        return Self(
            stage: retainedStage,
            targetPhraseNumber: targetPhraseNumber,
            isInitialTarget: isInitialTarget,
            attemptCount: counts.attempts,
            repeatCount: counts.repeats + 1,
            lastFailure: counts.failure
        )
    }

    package var headline: String {
        let target = targetPhraseNumber.map {
            "\(isInitialTarget ? "FIRST" : "NEXT") P\($0)"
        } ?? "NEXT PHRASE"
        return "\(target) · \(stageTitle)"
    }

    package func preparingInitial(targetPhraseNumber: Int) -> Self {
        let counts = counts(for: targetPhraseNumber, isInitial: true)
        return Self(
            stage: .preparing,
            targetPhraseNumber: targetPhraseNumber,
            isInitialTarget: true,
            attemptCount: counts.attempts + 1,
            repeatCount: counts.repeats,
            lastFailure: counts.failure
        )
    }

    package func blockedInitial(
        targetPhraseNumber: Int,
        failure: NextPhraseFailure
    ) -> Self {
        let counts = counts(for: targetPhraseNumber, isInitial: true)
        return Self(
            stage: .blocked,
            targetPhraseNumber: targetPhraseNumber,
            isInitialTarget: true,
            attemptCount: counts.attempts,
            repeatCount: counts.repeats,
            lastFailure: failure
        )
    }

    package func rejectedInitial(
        targetPhraseNumber: Int,
        failure: NextPhraseFailure
    ) -> Self {
        let counts = counts(for: targetPhraseNumber, isInitial: true)
        return Self(
            stage: .retrying,
            targetPhraseNumber: targetPhraseNumber,
            isInitialTarget: true,
            attemptCount: counts.attempts,
            repeatCount: counts.repeats,
            lastFailure: failure
        )
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
            if let lastFailure {
                parts.append(lastFailure.conciseLabel)
            }
        case .blocked:
            parts.append("PREPARATION BLOCKED")
            if let lastFailure {
                parts.append(lastFailure.conciseLabel)
            }
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
        case .blocked: "BLOCKED"
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
            isInitialTarget: false,
            attemptCount: counts.attempts,
            repeatCount: counts.repeats,
            lastFailure: counts.failure
        )
    }

    private func counts(for targetPhraseNumber: Int) -> (
        attempts: Int,
        repeats: Int,
        failure: NextPhraseFailure?
    ) {
        counts(for: targetPhraseNumber, isInitial: false)
    }

    private func counts(
        for targetPhraseNumber: Int,
        isInitial: Bool
    ) -> (
        attempts: Int,
        repeats: Int,
        failure: NextPhraseFailure?
    ) {
        guard self.targetPhraseNumber == targetPhraseNumber,
              isInitialTarget == isInitial else {
            return (0, 0, nil)
        }
        return (attemptCount, repeatCount, lastFailure)
    }
}
