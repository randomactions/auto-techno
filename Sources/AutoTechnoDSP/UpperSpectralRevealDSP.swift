import AutoTechnoCore
import Foundation

/// One mapping from the score-owned reveal aperture to each existing
/// architecture's requested cutoff. Home branches before arithmetic so the
/// current filter path remains exact.
package enum UpperSpectralRevealContract {
    package static func appliedCutoffHz(
        requestedCutoffHz: Double,
        articulation: UpperSpectralRevealArticulation,
        sampleRate: Double,
        maximumCutoffFraction: Double
    ) -> Double {
        guard requestedCutoffHz.isFinite,
              sampleRate.isFinite,
              sampleRate > 0,
              maximumCutoffFraction.isFinite,
              maximumCutoffFraction > 0 else {
            return TPTAntialiasedNonlinearCoreContract.minimumCutoffHz
        }
        let boundedRequested = min(
            sampleRate * maximumCutoffFraction,
            max(
                TPTAntialiasedNonlinearCoreContract.minimumCutoffHz,
                requestedCutoffHz
            )
        )
        guard articulation.relation == .emerging,
              articulation.aperture < 1 else {
            return boundedRequested
        }
        return min(
            sampleRate * maximumCutoffFraction,
            max(
                TPTAntialiasedNonlinearCoreContract.minimumCutoffHz,
                boundedRequested * articulation.aperture
            )
        )
    }
}
