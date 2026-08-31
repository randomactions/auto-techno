import Foundation

package enum UpperMusicalPumpSchema {
    package static let schemaVersion = 1
    package static let schemaIdentifier = "autotechno-upper-musical-pump.v1"
    package static let attackInBeats = 1.0 / 64.0
    package static let minimumReleaseInBeats = 3.0 / 8.0
    package static let maximumReleaseInBeats = 1.0 / 2.0
    package static let minimumAttenuation = 0.22
    package static let maximumAttenuation = 0.32
}

/// Score-owned gain geometry for the post-graph upper remainder. Kick anchors
/// come from the final post-syntax bar; the existing detector safety duck is
/// deliberately absent from this value and remains an independent renderer.
package struct UpperMusicalPumpArticulation: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let schemaIdentifier: String
    package let active: Bool
    package let kickAnchorSteps: [Int]
    package let attenuation: Double
    package let attackInBeats: Double
    package let releaseInBeats: Double

    package static let neutral = UpperMusicalPumpArticulation(
        active: false,
        kickAnchorSteps: [],
        attenuation: 0,
        releaseInBeats: UpperMusicalPumpSchema.minimumReleaseInBeats
    )

    package init(
        active: Bool,
        kickAnchorSteps: [Int],
        attenuation: Double,
        releaseInBeats: Double
    ) {
        schemaVersion = UpperMusicalPumpSchema.schemaVersion
        schemaIdentifier = UpperMusicalPumpSchema.schemaIdentifier
        let anchors = Array(Set(kickAnchorSteps.filter { (0..<16).contains($0) }))
            .sorted()
        let boundedAttenuation = attenuation.isFinite
            ? min(UpperMusicalPumpSchema.maximumAttenuation,
                  max(UpperMusicalPumpSchema.minimumAttenuation, attenuation))
            : 0
        let boundedRelease = releaseInBeats.isFinite
            ? min(UpperMusicalPumpSchema.maximumReleaseInBeats,
                  max(UpperMusicalPumpSchema.minimumReleaseInBeats,
                      releaseInBeats))
            : UpperMusicalPumpSchema.minimumReleaseInBeats
        self.active = active && !anchors.isEmpty && boundedAttenuation > 0
        self.kickAnchorSteps = self.active ? anchors : []
        self.attenuation = self.active ? boundedAttenuation : 0
        self.attackInBeats = UpperMusicalPumpSchema.attackInBeats
        self.releaseInBeats = boundedRelease
    }

    package var minimumGain: Double { 1 - attenuation }

    package var isValid: Bool {
        schemaVersion == UpperMusicalPumpSchema.schemaVersion &&
            schemaIdentifier == UpperMusicalPumpSchema.schemaIdentifier &&
            attackInBeats == UpperMusicalPumpSchema.attackInBeats &&
            releaseInBeats >= UpperMusicalPumpSchema.minimumReleaseInBeats &&
            releaseInBeats <= UpperMusicalPumpSchema.maximumReleaseInBeats &&
            (active
                ? (!kickAnchorSteps.isEmpty &&
                    attenuation >= UpperMusicalPumpSchema.minimumAttenuation &&
                    attenuation <= UpperMusicalPumpSchema.maximumAttenuation)
                : (kickAnchorSteps.isEmpty && attenuation == 0))
    }
}

package enum UpperMusicalPumpResolver {
    package static func articulation(
        resolved: ResolvedPerformanceBar,
        phraseKind: AutonomousPhraseKind,
        carrier: LongHorizonEffectCarrierArticulation
    ) -> UpperMusicalPumpArticulation {
        guard carrier.active, phraseKind != .identityReturn,
              carrier.requestedTarget != .neutral else { return .neutral }
        let anchors = resolved.ensemble.events.filter {
            $0.voice == .kick
        }.map(\.step)
        guard !anchors.isEmpty else { return .neutral }
        let target = carrier.requestedTarget
        let attenuation = UpperMusicalPumpSchema.minimumAttenuation +
            target.modulationMotion * 0.06 +
            target.nonlinearPressure * 0.04
        let release = UpperMusicalPumpSchema.minimumReleaseInBeats +
            target.echoMemory * (
                UpperMusicalPumpSchema.maximumReleaseInBeats -
                    UpperMusicalPumpSchema.minimumReleaseInBeats
            )
        return UpperMusicalPumpArticulation(
            active: true,
            kickAnchorSteps: anchors,
            attenuation: attenuation,
            releaseInBeats: release
        )
    }
}
