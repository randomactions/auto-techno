import AutoTechnoCore
@testable import AutoTechnoDSP
import Testing

/// Swift Testing retains render fixtures for the lifetime of its process on
/// hosted Swift 6.1 arm64. Keep this large-value fingerprint assertion in its
/// own file and suite so CI can execute it in a fresh process after rendering
/// tests.
@Suite("Live master trim fingerprint binding")
struct LiveMasterTrimFingerprintTests {
    @Test("Committed trim and revision are fingerprint-bound")
    func trimIsFingerprintBound() {
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

        #expect(home != attenuated)
        #expect(attenuated != newerRevision)

        let cancellableHome = cancellableFingerprint(liveState: homeState)
        let cancellableAttenuated = cancellableFingerprint(
            liveState: attenuatedState
        )
        let cancellableNewerRevision = cancellableFingerprint(
            liveState: newerRevisionState
        )
        #expect(cancellableHome != nil)
        #expect(cancellableAttenuated != nil)
        #expect(cancellableNewerRevision != nil)
        #expect(cancellableHome != cancellableAttenuated)
        #expect(cancellableAttenuated != cancellableNewerRevision)

        let negativeZeroState = LiveMasterHeadroomContinuationState(
            committedTrimDB: -0.0
        )
        #expect(negativeZeroState.committedTrimDB.bitPattern ==
                Double.zero.bitPattern)
        #expect(normalFingerprint(liveState: negativeZeroState) == home)
        #expect(cancellableFingerprint(liveState: negativeZeroState) ==
                cancellableHome)
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
