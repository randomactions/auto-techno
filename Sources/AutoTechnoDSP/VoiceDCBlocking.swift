import Foundation

/// Coefficients for the existing detached voice DC stage. The two previous-
/// sample fields remain owned by each voice's existing render continuation.
/// The reference is the exact authored 48 kHz realization, not a new preset.
struct VoiceDCBlocking: Equatable, Sendable {
    let pole: Double
    let differenceGain: Double

    /// Authored broadband sources retain their existing per-sample realization.
    /// This uses the same recurrence and caller-owned continuation as the
    /// physical-time realization; it introduces no additional filter or state.
    init?(authoredPole: Double) {
        guard authoredPole.isFinite, authoredPole > 0, authoredPole < 1 else { return nil }
        pole = authoredPole
        differenceGain = 1
    }

    init?(referencePole: Double, sampleRate: Double) {
        guard let authored = Self(authoredPole: referencePole),
              sampleRate.isFinite, sampleRate > 0 else { return nil }
        if sampleRate == 48_000 {
            self = authored
            return
        }
        let resolvedPole = exp(log(referencePole) * (48_000 / sampleRate))
        guard resolvedPole.isFinite, resolvedPole >= 0, resolvedPole < 1 else {
            return nil
        }
        pole = resolvedPole
        // H(-1) = 2*g/(1+p): preserve the authored reference's Nyquist gain.
        differenceGain = (1 + resolvedPole) / (1 + referencePole)
    }

    @inline(__always)
    func process(_ input: Double, previousInput: Double, previousOutput: Double) -> Double {
        let difference = input - previousInput
        // Keep the original arithmetic exactly on the reference route.
        let scaledDifference = differenceGain == 1 ? difference : differenceGain * difference
        return scaledDifference + pole * previousOutput
    }
}
