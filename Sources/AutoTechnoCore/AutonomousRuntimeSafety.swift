public struct AutonomousPreparationEpoch: Equatable, Sendable {
    public private(set) var value: Int

    public init(value: Int = 0) {
        self.value = max(0, value)
    }

    @discardableResult
    public mutating func invalidate() -> Int {
        value += 1
        return value
    }

    public func accepts(_ candidate: Int) -> Bool {
        candidate == value
    }
}

public enum AutonomousPhraseBoundaryDecision: Equatable, Sendable {
    case advance
    case repeatCurrentWithFrozenTopology
}

public enum AutonomousPhraseBoundaryPolicy {
    public static func decide(successorPrepared: Bool) -> AutonomousPhraseBoundaryDecision {
        successorPrepared ? .advance : .repeatCurrentWithFrozenTopology
    }
}
