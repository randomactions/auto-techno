import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Canonical render fingerprint parity")
struct RenderFingerprintParityTests {
    @Test func ordinaryAndCancellableIdentitiesAgree() {
        var state = RenderState()
        assertParity(state)
        state.spatialFDNState.storage = [Float](repeating: 0.125, count: 16_384)
        state.spatialFDNState.lineOffsets = [0, 4]
        state.spatialFDNState.lineLengths = [4, 8]
        state.spatialFDNState.writeIndices = [1, 2]
        state.spatialFDNState.dampingStates = [0.1, 0.2]
        state.spatialFDNState.appliedFeedbackGains = [0.3, 0.4]
        state.spatialFDNState.targetFeedbackGains = [0.5, 0.6]
        state.spatialFDNState.feedbackGainSteps = [0.01, 0.02]
        for key in scalarFields {
            state.spatialFDNState[keyPath: key] = 0.25
        }
        state.spatialFDNState.parameterTransitionRemainingFrames = 128
        state.liveMasterHeadroomState = LiveMasterHeadroomContinuationState(
            revision: 2, committedTrimDB: -0.5
        )
        assertParity(state)
        let baseline = AutonomousCandidateFingerprint.renderState(state)
        for key in scalarFields {
            state.spatialFDNState[keyPath: key] += 0.125
            #expect(AutonomousCandidateFingerprint.renderState(state) != baseline)
            assertParity(state)
            state.spatialFDNState[keyPath: key] -= 0.125
        }
        state.spatialFDNState.storage[8_192] += 0.125
        #expect(AutonomousCandidateFingerprint.renderState(state) != baseline)
        assertParity(state)
    }

    @Test func cancellationNeverPublishesAPartialFingerprint() {
        var state = RenderState()
        state.spatialFDNState.storage = [Float](repeating: 0.125, count: 16_384)
        let counter = CancellationProbe(cancelAt: .max)
        let complete = AutonomousCandidateFingerprint.renderState(
            state, cancellationRequested: counter.requested
        )
        #expect(complete == AutonomousCandidateFingerprint.renderState(state))
        #expect(counter.calls > 4)
        for boundary in 1...counter.calls {
            let probe = CancellationProbe(cancelAt: boundary)
            #expect(AutonomousCandidateFingerprint.renderState(
                state, cancellationRequested: probe.requested
            ) == nil)
        }
        #expect(AutonomousCandidateFingerprint.renderDSPContinuation(
            renderState: state, generatedDSPState: GeneratedDSPContinuationState(),
            cancellationRequested: { true }
        ) == nil)
    }

    @inline(never)
    private func assertParity(_ state: RenderState) {
        let ordinary = AutonomousCandidateFingerprint.renderState(state)
        let cancellable = AutonomousCandidateFingerprint.renderState(
            state, cancellationRequested: { false }
        )
        #expect(ordinary == cancellable)
        let graph = GeneratedDSPContinuationState()
        let combined = AutonomousCandidateFingerprint.renderDSPContinuation(
            renderState: state, generatedDSPState: graph
        )
        let cancellableCombined = AutonomousCandidateFingerprint.renderDSPContinuation(
            renderState: state, generatedDSPState: graph, cancellationRequested: { false }
        )
        #expect(combined == cancellableCombined)
    }

    private var scalarFields: [WritableKeyPath<FeedbackDelayNetworkState, Double>] {
        [\.routeSampleRate, \.geometryRoomScale, \.appliedDampingCoefficient,
         \.targetDampingCoefficient, \.dampingCoefficientStep, \.appliedSynthSendGain,
         \.targetSynthSendGain, \.synthSendGainStep, \.appliedPercussionSendGain,
         \.targetPercussionSendGain, \.percussionSendGainStep, \.appliedWetGain,
         \.targetWetGain, \.wetGainStep]
    }

    // Synchronous test-only probe; production hashing remains detached.
    private final class CancellationProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        let cancelAt: Int
        init(cancelAt: Int) { self.cancelAt = cancelAt }
        var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
        func requested() -> Bool {
            lock.lock(); defer { lock.unlock() }
            count += 1
            return count >= cancelAt
        }
    }
}
