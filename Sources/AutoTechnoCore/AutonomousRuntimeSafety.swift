package struct AutonomousPreparationEpoch: Equatable, Sendable {
    package private(set) var value: Int

    package init(value: Int = 0) {
        self.value = max(0, value)
    }

    @discardableResult
    package mutating func invalidate() -> Int {
        value += 1
        return value
    }

    package func accepts(_ candidate: Int) -> Bool {
        candidate == value
    }
}

package enum AutonomousPhraseBoundaryDecision: Equatable, Sendable {
    case advance
    case repeatCurrentWithFrozenTopology
}

package enum AutonomousPhraseBoundaryPolicy {
    package static func decide(successorPrepared: Bool) -> AutonomousPhraseBoundaryDecision {
        successorPrepared ? .advance : .repeatCurrentWithFrozenTopology
    }
}
