import Foundation

package enum MaskingRole: String, CaseIterable, Hashable, Sendable {
    case foundation
    case percussion
    case upper
}

package struct MaskingBand: Codable, Equatable, Sendable {
    package let name: String
    package let lowerHz: Double
    package let upperHz: Double

    package init(name: String, lowerHz: Double, upperHz: Double) {
        self.name = name
        self.lowerHz = lowerHz
        self.upperHz = upperHz
    }
}

/// Exact causal band-energy cells used by the masking analyzer. Exposing this
/// reduced evidence lets detached baseline tooling reuse the established band
/// filters without claiming that their overlapping one-pole differences are a
/// power-complementary filter bank.
package struct MaskingBandEnergyWindow: Codable, Equatable, Sendable {
    package let index: Int
    package let startFrame: Int
    package let frameCount: Int
    package let sourceMeanSquare: Double
    package let bandMeanSquares: [Double]

    package init(
        index: Int,
        startFrame: Int,
        frameCount: Int,
        sourceMeanSquare: Double,
        bandMeanSquares: [Double]
    ) {
        self.index = index
        self.startFrame = startFrame
        self.frameCount = frameCount
        self.sourceMeanSquare = sourceMeanSquare
        self.bandMeanSquares = bandMeanSquares
    }
}

/// One sample of the established causal masking filter bank. The bands are
/// deliberately overlapping one-pole differences rather than a
/// power-complementary crossover, so callers must preserve their names and
/// must not infer that their energies sum to source energy.
package struct MaskingBandFilterOutput: Equatable, Sendable {
    package let sub: Double
    package let lowMid: Double
    package let mid: Double
    package let high: Double

    package var values: [Double] {
        [sub, lowMid, mid, high]
    }

    package subscript(index: Int) -> Double {
        switch index {
        case 0: sub
        case 1: lowMid
        case 2: mid
        case 3: high
        default: preconditionFailure("masking band index out of range")
        }
    }
}

/// Reusable sample-by-sample owner of the masking analyzer's causal filter
/// coefficients and state. It is intended for detached evidence analysis;
/// production rendering does not use this filter bank.
package struct MaskingBandFilter: Sendable {
    private static let cutoffs = [35.0, 120.0, 420.0, 2_400.0, 10_000.0]

    private let coefficients: [Double]
    private var states = [Double](repeating: 0, count: cutoffs.count)

    package init?(sampleRate: Double) {
        guard sampleRate.isFinite, sampleRate > 0 else { return nil }
        coefficients = Self.cutoffs.map { cutoff in
            let boundedCutoff = min(cutoff, sampleRate * 0.45)
            return 1 - exp(-2 * Double.pi * boundedCutoff / sampleRate)
        }
    }

    package mutating func process(_ sample: Double) -> MaskingBandFilterOutput? {
        guard sample.isFinite else { return nil }
        for index in states.indices {
            states[index] += (sample - states[index]) * coefficients[index]
        }
        return MaskingBandFilterOutput(
            sub: states[1] - states[0],
            lowMid: states[2] - states[1],
            mid: states[3] - states[2],
            high: states[4] - states[3]
        )
    }
}

/// Reduced, role-truthful masking evidence. It records when two exact render
/// taps are simultaneously active and spectrally similar; it does not propose
/// or apply a mix correction while quality policy is uncalibrated.
package struct RoleMaskingObservation: Equatable, Sendable {
    package let band: MaskingBand
    package let firstRole: MaskingRole
    package let secondRole: MaskingRole
    package let analyzedWindowCount: Int
    package let activePairWindowCount: Int
    package let overlapWindowCount: Int
    package let longestOverlapRun: Int
    package let maximumOverlap: Double

    package var isPersistent: Bool {
        longestOverlapRun >= SpectrumMaskingAnalyzer.minimumPersistentWindows
    }

    package init(
        band: MaskingBand,
        firstRole: MaskingRole,
        secondRole: MaskingRole,
        analyzedWindowCount: Int,
        activePairWindowCount: Int,
        overlapWindowCount: Int,
        longestOverlapRun: Int,
        maximumOverlap: Double
    ) {
        self.band = band
        self.firstRole = firstRole
        self.secondRole = secondRole
        self.analyzedWindowCount = analyzedWindowCount
        self.activePairWindowCount = activePairWindowCount
        self.overlapWindowCount = overlapWindowCount
        self.longestOverlapRun = longestOverlapRun
        self.maximumOverlap = maximumOverlap
    }
}

/// Bounded detached-preparation analyzer over the complete rendered bar. The
/// fixed role/pair/window vector makes silence distinguishable from unavailable
/// or malformed evidence: valid silence returns twelve zero observations;
/// invalid input returns an empty vector.
package enum SpectrumMaskingAnalyzer {
    package static let bands = [
        MaskingBand(name: "sub", lowerHz: 35, upperHz: 120),
        MaskingBand(name: "low-mid", lowerHz: 120, upperHz: 420),
        MaskingBand(name: "mid", lowerHz: 420, upperHz: 2_400),
        MaskingBand(name: "high", lowerHz: 2_400, upperHz: 10_000),
    ]
    package static let analyzedWindowCount = 16
    package static let maximumFrames = 524_288
    package static let minimumPersistentWindows = 2
    package static let overlapThreshold = 0.38

    package static let activeMeanSquareThreshold = 0.000_000_000_1
    package static let rolePairs: [(MaskingRole, MaskingRole)] = [
        (.foundation, .percussion),
        (.foundation, .upper),
        (.percussion, .upper),
    ]

    package static func analyze(
        signals: [MaskingRole: [Float]],
        sampleRate: Double
    ) -> [RoleMaskingObservation] {
        guard sampleRate.isFinite, sampleRate > 0,
              Set(signals.keys) == Set(MaskingRole.allCases),
              let frameCount = signals[.foundation]?.count,
              frameCount >= analyzedWindowCount,
              frameCount <= maximumFrames,
              MaskingRole.allCases.allSatisfy({ signals[$0]?.count == frameCount }) else {
            return []
        }

        var energies: [MaskingRole: [MaskingBandEnergyWindow]] = [:]
        energies.reserveCapacity(MaskingRole.allCases.count)
        for role in MaskingRole.allCases {
            guard let signal = signals[role],
                  let roleAnalysis = bandEnergyWindows(
                    signal,
                    sampleRate: sampleRate
                  ) else {
                return []
            }
            energies[role] = roleAnalysis
        }

        var observations: [RoleMaskingObservation] = []
        observations.reserveCapacity(rolePairs.count * bands.count)
        for (firstRole, secondRole) in rolePairs {
            guard let first = energies[firstRole], let second = energies[secondRole] else {
                return []
            }
            for bandIndex in bands.indices {
                var activePairWindowCount = 0
                var overlapWindowCount = 0
                var currentOverlapRun = 0
                var longestOverlapRun = 0
                var maximumOverlap = 0.0
                for window in 0..<analyzedWindowCount {
                    let firstEnergy = first[window].bandMeanSquares[bandIndex]
                    let secondEnergy = second[window].bandMeanSquares[bandIndex]
                    // The causal analysis filters intentionally retain state
                    // across windows, but their decay must not invent source
                    // activity after an exact tap has become silent.
                    guard first[window].sourceMeanSquare > activeMeanSquareThreshold,
                          second[window].sourceMeanSquare > activeMeanSquareThreshold,
                          firstEnergy > activeMeanSquareThreshold,
                          secondEnergy > activeMeanSquareThreshold else {
                        currentOverlapRun = 0
                        continue
                    }
                    activePairWindowCount += 1
                    let overlap = min(firstEnergy, secondEnergy) /
                        max(firstEnergy, secondEnergy)
                    maximumOverlap = max(maximumOverlap, overlap)
                    if overlap > overlapThreshold {
                        overlapWindowCount += 1
                        currentOverlapRun += 1
                        longestOverlapRun = max(longestOverlapRun, currentOverlapRun)
                    } else {
                        currentOverlapRun = 0
                    }
                }
                observations.append(RoleMaskingObservation(
                    band: bands[bandIndex],
                    firstRole: firstRole,
                    secondRole: secondRole,
                    analyzedWindowCount: analyzedWindowCount,
                    activePairWindowCount: activePairWindowCount,
                    overlapWindowCount: overlapWindowCount,
                    longestOverlapRun: longestOverlapRun,
                    maximumOverlap: maximumOverlap
                ))
            }
        }
        return observations
    }

    package static func bandEnergyWindows(
        _ samples: [Float],
        sampleRate: Double
    ) -> [MaskingBandEnergyWindow]? {
        guard sampleRate.isFinite, sampleRate > 0,
              samples.count >= analyzedWindowCount,
              samples.count <= maximumFrames else {
            return nil
        }
        guard var filter = MaskingBandFilter(sampleRate: sampleRate) else {
            return nil
        }
        var energySums = Array(
            repeating: [Double](repeating: 0, count: bands.count),
            count: analyzedWindowCount
        )
        var frameCounts = [Int](repeating: 0, count: analyzedWindowCount)
        var sourceEnergySums = [Double](repeating: 0, count: analyzedWindowCount)

        for (frame, sample) in samples.enumerated() {
            let input = Double(sample)
            guard let output = filter.process(input) else { return nil }
            let window = min(
                analyzedWindowCount - 1,
                frame * analyzedWindowCount / samples.count
            )
            frameCounts[window] += 1
            sourceEnergySums[window] += input * input
            for band in bands.indices {
                energySums[window][band] += output[band] * output[band]
            }
        }

        var windows: [MaskingBandEnergyWindow] = []
        windows.reserveCapacity(analyzedWindowCount)
        var startFrame = 0
        for window in 0..<analyzedWindowCount {
            let divisor = Double(max(1, frameCounts[window]))
            sourceEnergySums[window] /= divisor
            for band in bands.indices {
                energySums[window][band] /= divisor
            }
            windows.append(MaskingBandEnergyWindow(
                index: window,
                startFrame: startFrame,
                frameCount: frameCounts[window],
                sourceMeanSquare: sourceEnergySums[window],
                bandMeanSquares: energySums[window]
            ))
            startFrame += frameCounts[window]
        }
        return windows
    }
}
