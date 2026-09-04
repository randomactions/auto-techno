import AutoTechnoCore
@testable import AutoTechnoDSP
import XCTest

/// Swift Testing retains render fixtures for the lifetime of its process on
/// hosted Swift 6.1 arm64, and its cooperative-task stack faults while entering
/// this large-value fingerprint assertion. Keep the exact assertion in a
/// synchronous XCTest case and a fresh CI process after rendering tests.
final class LiveMasterTrimFingerprintTests: XCTestCase {
    func testTrimIsFingerprintBound() {
        let homeState = LiveMasterHeadroomContinuationState()
        let attenuatedState = liveState(trimDB: -0.5)
        let newerRevisionState = LiveMasterHeadroomContinuationState(
            revision: 8,
            committedTrimDB: -0.5,
            consecutiveCleanWindows: 1,
            lastProposalFingerprint: "proposal-8",
            lastObservationFingerprint: "observation-8",
            lastAcceptedSourcePhraseIndex: 5,
            earliestEligibleFutureSample: 96_000
        )

        let home = normalFingerprint(liveState: homeState)
        let attenuated = normalFingerprint(liveState: attenuatedState)
        let newerRevision = normalFingerprint(liveState: newerRevisionState)

        XCTAssertNotEqual(home, attenuated)
        XCTAssertNotEqual(attenuated, newerRevision)

        let cancellableHome = cancellableFingerprint(liveState: homeState)
        let cancellableAttenuated = cancellableFingerprint(
            liveState: attenuatedState
        )
        let cancellableNewerRevision = cancellableFingerprint(
            liveState: newerRevisionState
        )
        XCTAssertNotNil(cancellableHome)
        XCTAssertNotNil(cancellableAttenuated)
        XCTAssertNotNil(cancellableNewerRevision)
        XCTAssertNotEqual(cancellableHome, cancellableAttenuated)
        XCTAssertNotEqual(cancellableAttenuated, cancellableNewerRevision)

        let negativeZeroState = LiveMasterHeadroomContinuationState(
            committedTrimDB: -0.0
        )
        XCTAssertEqual(
            negativeZeroState.committedTrimDB.bitPattern,
            Double.zero.bitPattern
        )
        XCTAssertEqual(normalFingerprint(liveState: negativeZeroState), home)
        XCTAssertEqual(
            cancellableFingerprint(liveState: negativeZeroState),
            cancellableHome
        )
    }

    private func liveState(trimDB: Double) -> LiveMasterHeadroomContinuationState {
        LiveMasterHeadroomContinuationState(
            revision: 7,
            committedTrimDB: trimDB,
            consecutiveCleanWindows: 1,
            lastProposalFingerprint: "proposal-7",
            lastObservationFingerprint: "observation-7",
            lastAcceptedSourcePhraseIndex: 4,
            earliestEligibleFutureSample: 64_000
        )
    }

    /// Keep one state and one fingerprint path in each non-inlined helper so
    /// the compiler cannot merge multiple `RenderState` frames into the test.
    @inline(never)
    private func normalFingerprint(
        liveState: LiveMasterHeadroomContinuationState
    ) -> String {
        var renderState = RenderState()
        renderState.liveMasterHeadroomState = liveState
        return AutonomousCandidateFingerprint.renderState(renderState)
    }

    @inline(never)
    private func cancellableFingerprint(
        liveState: LiveMasterHeadroomContinuationState
    ) -> String? {
        var renderState = RenderState()
        renderState.liveMasterHeadroomState = liveState
        return AutonomousCandidateFingerprint.renderState(
            renderState,
            cancellationRequested: { false }
        )
    }
}
