import Testing
@testable import AutoTechnoCore

@Suite("Upper spectral reveal")
struct UpperSpectralRevealTests {
    @Test("Emerging narrative opens one bounded anchor aperture")
    func apertureGeometry() {
        let narrative = NarrativeArticulation(
            presenceStart: 0.20,
            presenceEnd: 0.80,
            activeSupportingRoles: [.percussion]
        )
        let start = UpperSpectralRevealResolver.articulation(
            role: .anchor,
            narrative: narrative,
            phraseKind: .lock,
            forceHome: false,
            step: 0
        )
        let middle = UpperSpectralRevealResolver.articulation(
            role: .anchor,
            narrative: narrative,
            phraseKind: .lock,
            forceHome: false,
            step: 8
        )
        let end = UpperSpectralRevealResolver.articulation(
            role: .anchor,
            narrative: narrative,
            phraseKind: .lock,
            forceHome: false,
            step: 15
        )

        #expect(start.relation == .emerging)
        #expect(start.aperture >= UpperSpectralRevealArticulation.minimumAperture)
        #expect(start.aperture < middle.aperture)
        #expect(middle.aperture < end.aperture)
        #expect(end.aperture < 1)
        #expect(start == UpperSpectralRevealResolver.articulation(
            role: .anchor,
            narrative: narrative,
            phraseKind: .lock,
            forceHome: false,
            step: 0
        ))
    }

    @Test("Supporting roles and home boundaries remain exact")
    func neutralBoundaries() {
        let emerging = NarrativeArticulation(
            presenceStart: 0.25,
            presenceEnd: 0.75,
            activeSupportingRoles: [.response]
        )
        let holding = NarrativeArticulation(
            presenceStart: 0.65,
            presenceEnd: 0.65,
            activeSupportingRoles: [.response]
        )
        for role in [SynthRole.shadow, .response, .atmosphere, .transition] {
            #expect(UpperSpectralRevealResolver.articulation(
                role: role,
                narrative: emerging,
                phraseKind: .contrast,
                forceHome: false,
                step: 7
            ) == .home)
        }
        for kind in [AutonomousPhraseKind.majorBreak, .energyRelease,
                     .identityReturn] {
            #expect(UpperSpectralRevealResolver.articulation(
                role: .anchor,
                narrative: emerging,
                phraseKind: kind,
                forceHome: false,
                step: 7
            ) == .home)
        }
        #expect(UpperSpectralRevealResolver.articulation(
            role: .anchor,
            narrative: holding,
            phraseKind: .lock,
            forceHome: false,
            step: 7
        ) == .home)
        #expect(UpperSpectralRevealResolver.articulation(
            role: .anchor,
            narrative: emerging,
            phraseKind: .lock,
            forceHome: true,
            step: 7
        ) == .home)
        #expect(UpperSpectralRevealArticulation(
            relation: .emerging,
            aperture: .nan
        ) == .home)
    }
}
