import Foundation

/// Chooses one opaque identity before an autonomous session begins. Entropy is
/// never consulted by detached rendering or the realtime audio path; once
/// selected, the seed is ordinary deterministic score provenance.
@MainActor
package final class AutonomousSessionSeedSource {
    private static let collisionStep: UInt64 = 0x9E3779B97F4A7C15

    private let drawEntropy: @MainActor () -> UInt64

    package init(
        drawEntropy: @escaping @MainActor () -> UInt64 = {
            var generator = SystemRandomNumberGenerator()
            return generator.next()
        }
    ) {
        self.drawEntropy = drawEntropy
    }

    package func nextSeed(excluding previous: UInt64? = nil) -> UInt64 {
        let candidate = drawEntropy()
        guard candidate == previous else { return candidate }
        return candidate &+ Self.collisionStep
    }
}
