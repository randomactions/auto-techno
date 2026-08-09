import Foundation

package enum MaskingRole: String, CaseIterable, Hashable, Sendable {
    case foundation
    case percussion
    case upper
}

package struct MaskingBand: Equatable, Sendable {
    package let name: String
    package let lowerHz: Double
    package let upperHz: Double

    package init(name: String, lowerHz: Double, upperHz: Double) {
        self.name = name
        self.lowerHz = lowerHz
        self.upperHz = upperHz
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

    private static let activeMeanSquareThreshold = 0.000_000_000_1
    private static let overlapThreshold = 0.38
    private static let cutoffs = [35.0, 120.0, 420.0, 2_400.0, 10_000.0]
    private static let rolePairs: [(MaskingRole, MaskingRole)] = [
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

        var energies: [MaskingRole: [[Double]]] = [:]
        var sourceEnergies: [MaskingRole: [Double]] = [:]
        energies.reserveCapacity(MaskingRole.allCases.count)
        sourceEnergies.reserveCapacity(MaskingRole.allCases.count)
        for role in MaskingRole.allCases {
            guard let signal = signals[role],
                  let roleAnalysis = windowBandEnergies(
                    signal,
                    sampleRate: sampleRate
                  ) else {
                return []
            }
            energies[role] = roleAnalysis.bandEnergies
            sourceEnergies[role] = roleAnalysis.sourceEnergies
        }

        var observations: [RoleMaskingObservation] = []
        observations.reserveCapacity(rolePairs.count * bands.count)
        for (firstRole, secondRole) in rolePairs {
            guard let first = energies[firstRole], let second = energies[secondRole],
                  let firstSource = sourceEnergies[firstRole],
                  let secondSource = sourceEnergies[secondRole] else {
                return []
            }
            for bandIndex in bands.indices {
                var activePairWindowCount = 0
                var overlapWindowCount = 0
                var currentOverlapRun = 0
                var longestOverlapRun = 0
                var maximumOverlap = 0.0
                for window in 0..<analyzedWindowCount {
                    let firstEnergy = first[window][bandIndex]
                    let secondEnergy = second[window][bandIndex]
                    // The causal analysis filters intentionally retain state
                    // across windows, but their decay must not invent source
                    // activity after an exact tap has become silent.
                    guard firstSource[window] > activeMeanSquareThreshold,
                          secondSource[window] > activeMeanSquareThreshold,
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

    private static func windowBandEnergies(
        _ samples: [Float],
        sampleRate: Double
    ) -> (bandEnergies: [[Double]], sourceEnergies: [Double])? {
        let coefficients = cutoffs.map { cutoff in
            let boundedCutoff = min(cutoff, sampleRate * 0.45)
            return 1 - exp(-2 * Double.pi * boundedCutoff / sampleRate)
        }
        var filterStates = [Double](repeating: 0, count: cutoffs.count)
        var energySums = Array(
            repeating: [Double](repeating: 0, count: bands.count),
            count: analyzedWindowCount
        )
        var frameCounts = [Int](repeating: 0, count: analyzedWindowCount)
        var sourceEnergySums = [Double](repeating: 0, count: analyzedWindowCount)

        for (frame, sample) in samples.enumerated() {
            let input = Double(sample)
            guard input.isFinite else { return nil }
            for cutoffIndex in cutoffs.indices {
                filterStates[cutoffIndex] +=
                    (input - filterStates[cutoffIndex]) * coefficients[cutoffIndex]
            }
            let window = min(
                analyzedWindowCount - 1,
                frame * analyzedWindowCount / samples.count
            )
            frameCounts[window] += 1
            sourceEnergySums[window] += input * input
            let sub = filterStates[1] - filterStates[0]
            let lowMid = filterStates[2] - filterStates[1]
            let mid = filterStates[3] - filterStates[2]
            let high = filterStates[4] - filterStates[3]
            energySums[window][0] += sub * sub
            energySums[window][1] += lowMid * lowMid
            energySums[window][2] += mid * mid
            energySums[window][3] += high * high
        }

        for window in 0..<analyzedWindowCount {
            let divisor = Double(max(1, frameCounts[window]))
            sourceEnergySums[window] /= divisor
            for band in bands.indices {
                energySums[window][band] /= divisor
            }
        }
        return (energySums, sourceEnergySums)
    }
}
