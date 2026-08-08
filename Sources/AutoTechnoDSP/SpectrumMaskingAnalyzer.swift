import Foundation

public enum MaskingRole: String, CaseIterable, Sendable {
    case kickBass = "kick/bass"
    case percussion
    case synth
    case texture
}

public struct MaskingBand: Equatable, Sendable {
    public let name: String
    public let lowerHz: Double
    public let upperHz: Double

    public init(name: String, lowerHz: Double, upperHz: Double) {
        self.name = name; self.lowerHz = lowerHz; self.upperHz = upperHz
    }
}

public struct MaskingDecision: Equatable, Sendable {
    public let band: MaskingBand
    public let protectedRole: MaskingRole
    public let yieldingRole: MaskingRole
    public let overlap: Double
    public let cut: Double
    public let reason: String

    public init(band: MaskingBand, protectedRole: MaskingRole, yieldingRole: MaskingRole,
                overlap: Double, cut: Double, reason: String) {
        self.band = band; self.protectedRole = protectedRole; self.yieldingRole = yieldingRole
        self.overlap = overlap; self.cut = cut; self.reason = reason
    }
}

/// Small, deterministic spectral guard. It is intended for preparation-time
/// analysis; it performs no realtime work and has no mutable global state.
public enum SpectrumMaskingAnalyzer {
    public static let bands = [
        MaskingBand(name: "sub", lowerHz: 35, upperHz: 120),
        MaskingBand(name: "low-mid", lowerHz: 120, upperHz: 420),
        MaskingBand(name: "mid", lowerHz: 420, upperHz: 2_400),
        MaskingBand(name: "high", lowerHz: 2_400, upperHz: 10_000)
    ]

    public static func analyze(signals: [MaskingRole: [Float]], sampleRate: Double,
                               persistence: Int = 2) -> [MaskingDecision] {
        let energies = Dictionary(uniqueKeysWithValues: MaskingRole.allCases.map { role in
            (role, bandEnergies(signals[role] ?? [], sampleRate: sampleRate))
        })
        var result: [MaskingDecision] = []
        for bandIndex in bands.indices {
            let kick = energies[.kickBass]![bandIndex]
            let percussion = energies[.percussion]![bandIndex]
            let synth = energies[.synth]![bandIndex]
            let texture = energies[.texture]![bandIndex]
            let pairs: [(MaskingRole, Double, MaskingRole, Double)] = [
                (.kickBass, kick, .synth, synth), (.kickBass, kick, .texture, texture),
                (.percussion, percussion, .synth, synth), (.percussion, percussion, .texture, texture),
                (.synth, synth, .texture, texture)
            ]
            for (protected, protectedEnergy, yielding, yieldingEnergy) in pairs {
                guard protectedEnergy > 0.000001, yieldingEnergy > 0.000001 else { continue }
                let overlap = min(protectedEnergy, yieldingEnergy) / max(protectedEnergy, yieldingEnergy)
                guard overlap > 0.38 else { continue }
                let persistenceFactor = min(1, Double(max(1, persistence)) / 4)
                let cut = min(0.24, max(0.035, (overlap - 0.30) * 0.22) * persistenceFactor)
                result.append(MaskingDecision(band: bands[bandIndex], protectedRole: protected,
                    yieldingRole: yielding, overlap: overlap, cut: cut,
                    reason: protected == .kickBass ? "Protect kick/bass clarity" : "Reduce shared \(bands[bandIndex].name) cloud"))
            }
        }
        return result
    }

    private static func bandEnergies(_ samples: [Float], sampleRate: Double) -> [Double] {
        guard !samples.isEmpty else { return bands.map { _ in 0 } }
        // A fixed 256-sample analysis frame keeps preparation bounded while
        // still resolving the four broad musical bands.
        let n = min(samples.count, 256)
        let input = Array(samples.prefix(n))
        return bands.map { band in
            var energy = 0.0
            let first = max(1, Int((band.lowerHz * Double(n) / sampleRate).rounded()))
            let last = min(n / 2, Int((band.upperHz * Double(n) / sampleRate).rounded()))
            guard first <= last else { return 0 }
            for bin in first...last {
                var real = 0.0; var imaginary = 0.0
                for (index, sample) in input.enumerated() {
                    let angle = 2 * Double.pi * Double(bin * index) / Double(n)
                    let window = 0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(max(1, n - 1)))
                    real += Double(sample) * window * cos(angle)
                    imaginary -= Double(sample) * window * sin(angle)
                }
                energy += (real * real + imaginary * imaginary) / Double(n * n)
            }
            return energy / Double(last - first + 1)
        }
    }
}
