import Foundation

/// Durable meaning for an already-resolved dominant motif's filter opening.
/// The score owns the relationship; each compatible renderer owns its cutoff
/// topology and may replace that implementation without changing this intent.
package enum UpperSpectralRevealRelation: String, CaseIterable, Sendable {
    case home
    case emerging
}

package struct UpperSpectralRevealArticulation: Equatable, Sendable {
    package static let minimumAperture = 0.45

    package let relation: UpperSpectralRevealRelation
    package let aperture: Double

    package init(relation: UpperSpectralRevealRelation, aperture: Double) {
        guard relation == .emerging, aperture.isFinite else {
            self.relation = .home
            self.aperture = 1
            return
        }
        let bounded = min(1, max(Self.minimumAperture, aperture))
        if bounded < 1 {
            self.relation = .emerging
            self.aperture = bounded
        } else {
            self.relation = .home
            self.aperture = 1
        }
    }

    package static let home = UpperSpectralRevealArticulation(
        relation: .home,
        aperture: 1
    )
}

/// Extends the existing narrative protagonist rather than creating another
/// automation lane. Only the anchor can disclose detail; supporting and
/// protected roles retain their own canonical spectral owners.
package enum UpperSpectralRevealResolver {
    package static func articulation(
        role: SynthRole,
        narrative: NarrativeArticulation,
        phraseKind: AutonomousPhraseKind,
        forceHome: Bool,
        step: Int
    ) -> UpperSpectralRevealArticulation {
        guard !forceHome,
              role == .anchor,
              narrative.direction == .emerging,
              phraseKind == .lock || phraseKind == .contrast else {
            return .home
        }
        let presence = narrative.presence(atStep: step)
        let aperture = UpperSpectralRevealArticulation.minimumAperture +
            (1 - UpperSpectralRevealArticulation.minimumAperture) *
            presence * presence
        return UpperSpectralRevealArticulation(
            relation: .emerging,
            aperture: aperture
        )
    }
}
