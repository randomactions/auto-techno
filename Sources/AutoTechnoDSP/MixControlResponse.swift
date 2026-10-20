import Foundation

/// Immutable physical-time coefficients for VoiceRenderer's existing bar-local
/// mix controls. The renderer still owns and initializes every mutable scalar.
/// No filter, continuation, buffer, pass or user parameter is added.
struct MixControlResponse: Equatable, Sendable {
    let kickRelease: Double
    let upperLow: Double
    let upperMid: Double
    let midDetector: Double
    let upperTone: Double
    let highDetector: Double
    let centerLow: Double

    init(sampleRate: Double) {
        precondition(sampleRate.isFinite && sampleRate > 0)
        if sampleRate == 48_000 {
            // Retain the exact authored literals and the caller's arithmetic.
            kickRelease = 0.992
            upperLow = 0.012
            upperMid = 0.055
            midDetector = 0.014
            upperTone = 0.11
            highDetector = 0.018
            centerLow = 0.045
        } else {
            let scale = 48_000 / sampleRate
            kickRelease = exp(log(0.992) * scale)
            upperLow = Self.lowpass(0.012, scale: scale)
            upperMid = Self.lowpass(0.055, scale: scale)
            midDetector = Self.lowpass(0.014, scale: scale)
            upperTone = Self.lowpass(0.11, scale: scale)
            highDetector = Self.lowpass(0.018, scale: scale)
            centerLow = Self.lowpass(0.045, scale: scale)
        }
    }

    private static func lowpass(_ authored: Double, scale: Double) -> Double {
        1 - exp(log(1 - authored) * scale)
    }
}
