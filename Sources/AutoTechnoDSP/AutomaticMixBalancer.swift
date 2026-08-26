import AutoTechnoCore
import Foundation

/// Musical role groups used by the preparation-time mixer. These are internal
/// render buses, not product controls.
package enum MixRole: String, CaseIterable, Hashable, Sendable {
    case kick
    case foundation
    case percussion
    case upperTonal
    case atmosphere
}

package enum MixBand: String, CaseIterable, Hashable, Sendable {
    case sub
    case bass
    case lowMid
    case mid
    case high
}

package struct StemObservation: Equatable, Sendable {
    package let rms: Double
    package let activeRMS: Double
    package let onsetRMS: Double
    package let peak: Double
    package let crestFactor: Double
    package let occupancy: Double
    package let bandEnergy: [MixBand: Double]

    package init(rms: Double, activeRMS: Double, onsetRMS: Double,
                 peak: Double, crestFactor: Double, occupancy: Double,
                 bandEnergy: [MixBand: Double]) {
        self.rms = rms
        self.activeRMS = activeRMS
        self.onsetRMS = onsetRMS
        self.peak = peak
        self.crestFactor = crestFactor
        self.occupancy = occupancy
        self.bandEnergy = bandEnergy
    }

    package static let silent = StemObservation(
        rms: 0, activeRMS: 0, onsetRMS: 0, peak: 0,
        crestFactor: 0, occupancy: 0,
        bandEnergy: Dictionary(uniqueKeysWithValues: MixBand.allCases.map { ($0, 0) })
    )

    package var activeDB: Double {
        20 * log10(max(activeRMS, 0.000_000_001))
    }

    package var onsetDB: Double {
        20 * log10(max(onsetRMS, 0.000_000_001))
    }
}

package struct AutomaticMixPlan: Equatable, Sendable {
    package let gainsDB: [MixRole: Double]
    package let measuredKickOverFoundationDB: Double?
    package let targetKickOverFoundationDB: Double?
    /// Exact pre-fader source measurements used by the controller. Active RMS
    /// is not invertible from the post-fader stem because its activity gate can
    /// change sample membership after Float gain; ungated RMS binds the source
    /// measurement to the rendered post-fader stem instead.
    package let sourceKickRMS: Double?
    package let sourceKickActiveRMS: Double?

    package init(gainsDB: [MixRole: Double] = [:],
                 measuredKickOverFoundationDB: Double? = nil,
                 targetKickOverFoundationDB: Double? = nil,
                 sourceKickRMS: Double? = nil,
                 sourceKickActiveRMS: Double? = nil) {
        self.gainsDB = Dictionary(uniqueKeysWithValues: MixRole.allCases.map {
            ($0, gainsDB[$0] ?? 0)
        })
        self.measuredKickOverFoundationDB = measuredKickOverFoundationDB
        self.targetKickOverFoundationDB = targetKickOverFoundationDB
        self.sourceKickRMS = sourceKickRMS
        self.sourceKickActiveRMS = sourceKickActiveRMS
    }

    package static let unity = AutomaticMixPlan()

    package func gain(for role: MixRole) -> Double {
        pow(10, (gainsDB[role] ?? 0) / 20)
    }
}

/// Bounded continuation for the automatic fader. The current candidate remains
/// the upper limit: the governor may trim the kick or recover toward its home
/// correction, but it never boosts above the authored post-fader level.
package struct AutomaticMixState: Equatable, Sendable {
    package var kickCorrectionDB: Double

    package init(kickCorrectionDB: Double = -1.0) {
        self.kickCorrectionDB = min(0, max(-3, kickCorrectionDB))
    }
}

package enum AutomaticMixBalancer {
    package static let minimumKickCorrectionDB = -3.0
    package static let homeKickCorrectionDB = -1.0
    package static let maximumStepDB = 0.35
    package static let deadbandDB = 0.35

    package static func resolve(observations: [MixRole: StemObservation],
                                companion: FoundationCompanion,
                                section: SectionKind,
                                state: inout AutomaticMixState) -> AutomaticMixPlan {
        let kick = observations[.kick] ?? .silent
        let foundation = observations[.foundation] ?? .silent
        guard kick.activeRMS > 0 else {
            return plan(state: state)
        }
        guard section != .breakdown, companion != .empty,
              foundation.activeRMS > 0.000_001, foundation.occupancy >= 0.02 else {
            return plan(state: state)
        }

        let measuredDifference = kick.activeDB - foundation.activeDB
        let targetDifference = targetDifferenceDB(for: companion)
        let effectiveDifference = measuredDifference + state.kickCorrectionDB
        let error = targetDifference - effectiveDifference
        if abs(error) > deadbandDB {
            let step = min(maximumStepDB, max(-maximumStepDB, error * 0.5))
            state.kickCorrectionDB = min(
                0,
                max(minimumKickCorrectionDB, state.kickCorrectionDB + step)
            )
        }
        return AutomaticMixPlan(
            gainsDB: [.kick: state.kickCorrectionDB],
            measuredKickOverFoundationDB: measuredDifference,
            targetKickOverFoundationDB: targetDifference,
            sourceKickRMS: kick.rms,
            sourceKickActiveRMS: kick.activeRMS
        )
    }

    private static func plan(state: AutomaticMixState) -> AutomaticMixPlan {
        AutomaticMixPlan(gainsDB: [.kick: state.kickCorrectionDB])
    }

    private static func targetDifferenceDB(for companion: FoundationCompanion) -> Double {
        switch companion {
        case .bass: 16.5
        case .monoRumble: 27.5
        case .tunedTom: 22.5
        case .empty: 0
        }
    }
}

/// Deterministic full-bar stem measurement. The broad filter bank is cheap,
/// stable across sample rates, and runs only while immutable audio is prepared.
package enum StemObservationAnalyzer {
    package static func analyze(_ samples: [Float], sampleRate: Double,
                                onsetFrames: [Int] = [],
                                onsetWindowSeconds: Double = 0.09) -> StemObservation {
        guard !samples.isEmpty, sampleRate > 0 else { return .silent }
        let peak = samples.reduce(0.0) { max($0, abs(Double($1))) }
        guard peak > 0.000_000_001 else { return .silent }

        // The activity threshold must never exceed a stem that already passed
        // the explicit silence floor. Otherwise a very quiet but truthful stem
        // reports nonzero RMS/peak with zero active RMS and occupancy.
        let gate = min(peak, max(0.000_01, peak * 0.04))
        var totalEnergy = 0.0
        var activeEnergy = 0.0
        var activeCount = 0
        var low90 = 0.0
        var low180 = 0.0
        var low500 = 0.0
        var low2K5 = 0.0
        var energies = Dictionary(uniqueKeysWithValues: MixBand.allCases.map { ($0, 0.0) })
        let coefficient90 = 1 - exp(-2 * Double.pi * 90 / sampleRate)
        let coefficient180 = 1 - exp(-2 * Double.pi * 180 / sampleRate)
        let coefficient500 = 1 - exp(-2 * Double.pi * 500 / sampleRate)
        let coefficient2K5 = 1 - exp(-2 * Double.pi * 2_500 / sampleRate)

        for sampleValue in samples {
            let sample = Double(sampleValue)
            let energy = sample * sample
            totalEnergy += energy
            if abs(sample) >= gate {
                activeEnergy += energy
                activeCount += 1
            }
            low90 += (sample - low90) * coefficient90
            low180 += (sample - low180) * coefficient180
            low500 += (sample - low500) * coefficient500
            low2K5 += (sample - low2K5) * coefficient2K5
            let components: [(MixBand, Double)] = [
                (.sub, low90),
                (.bass, low180 - low90),
                (.lowMid, low500 - low180),
                (.mid, low2K5 - low500),
                (.high, sample - low2K5),
            ]
            for (band, value) in components {
                energies[band, default: 0] += value * value
            }
        }

        let onsetWindow = max(1, Int((sampleRate * onsetWindowSeconds).rounded()))
        var onsetEnergy = 0.0
        var onsetCount = 0
        var included = [Bool](repeating: false, count: samples.count)
        for start in onsetFrames {
            let lower = min(samples.count, max(0, start))
            let upper = min(samples.count, lower + onsetWindow)
            guard lower < upper else { continue }
            for index in lower..<upper where !included[index] {
                included[index] = true
                let sample = Double(samples[index])
                onsetEnergy += sample * sample
                onsetCount += 1
            }
        }

        let rms = sqrt(totalEnergy / Double(samples.count))
        let activeRMS = activeCount > 0 ? sqrt(activeEnergy / Double(activeCount)) : 0
        let onsetRMS = onsetCount > 0 ? sqrt(onsetEnergy / Double(onsetCount)) : activeRMS
        let normalizedBands = Dictionary(uniqueKeysWithValues: MixBand.allCases.map {
            ($0, energies[$0, default: 0] / Double(samples.count))
        })
        return StemObservation(
            rms: rms,
            activeRMS: activeRMS,
            onsetRMS: onsetRMS,
            peak: peak,
            crestFactor: peak / max(rms, 0.000_000_001),
            occupancy: Double(activeCount) / Double(samples.count),
            bandEnergy: normalizedBands
        )
    }
}
