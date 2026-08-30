import AutoTechnoCore
import Foundation
import Testing

@Suite("Modal percussion planning", .serialized)
struct ModalPercussionPlanningTests {
    @Test("Resolution preserves the existing foundation score events")
    func preservesExistingFoundationEvents() {
        let fixture = fixture()
        let before = fixture.ensemble.events

        let articulations = resolve(fixture)

        #expect(fixture.ensemble.events == before)
        #expect(articulations.count == 2)
        #expect(articulations.map(\.scoreEventIndex) == [1, 2])
    }

    @Test("Resolved modal relations are deterministic and bounded")
    func deterministicBoundedModalRelations() {
        let fixture = fixture()

        let first = resolve(fixture)
        let replay = resolve(fixture)

        #expect(first == replay)
        #expect(first.map(\.scoreEventIndex) == first.map(\.scoreEventIndex).sorted())
        #expect(first.allSatisfy { $0.use == .foundationCompanion })
        #expect(first.allSatisfy { fixture.dna.modalDegrees.contains($0.modalDegree) })
        #expect(first.allSatisfy { (48.0...196.0).contains($0.fundamentalHz) })
        #expect(first.allSatisfy { (0.0...1.0).contains($0.excitation) })
        #expect(first.allSatisfy { (0.0...1.0).contains($0.damping) })
        #expect(first.allSatisfy { (0.0...1.0).contains($0.brightness) })
        #expect(first.allSatisfy { (0.0...0.12).contains($0.inharmonicity) })
        #expect(first.allSatisfy {
            ModalPercussionMaterial.allCases.contains($0.material)
        })
        #expect(first.allSatisfy { (0.0...0.6).contains($0.coupling) })
        #expect(first.allSatisfy { articulation in
            fixture.ensemble.events[articulation.scoreEventIndex].intensity ==
                articulation.eventIntensity
        })
        #expect(first.allSatisfy { articulation in
            fixture.ensemble.events[articulation.scoreEventIndex].step == articulation.step
        })
    }

    @Test("Held rhythm worlds resolve four distinct physical materials")
    func rhythmWorldsResolveDistinctPhysicalMaterials() {
        let fixture = fixture()
        let expected: [(LongHorizonRhythmLanguage, ModalPercussionMaterial)] = [
            (.fourOnFloor, .stretchedMembrane),
            (.brokenGrid, .hollowWood),
            (.crossPulse, .bronzePlate),
            (.negativeSpace, .ceramicShell),
        ]
        let resolved = expected.map { rhythm, material in
            let articulations = resolve(
                fixture,
                rhythmLanguage: rhythm,
                materialArchitecture: .hybrid
            )
            #expect(articulations.allSatisfy { $0.material == material })
            return articulations
        }

        #expect(Set(resolved.compactMap(\.first).map {
            $0.material.rawValue
        }).count == 4)
        #expect(Set(resolved.compactMap(\.first).map(\.coupling)).count == 4)
    }

    @Test("Two strikes retain a modal relationship when the motif has one degree")
    func twoStrikesAreRelational() {
        guard let fixture = singleDegreeFixture() else {
            Issue.record("Expected a deterministic single-degree motif fixture")
            return
        }

        let articulations = resolve(fixture)

        #expect(articulations.count == 2)
        #expect(Set(articulations.map(\.modalDegree)).count == 2)
        #expect(articulations.allSatisfy { fixture.dna.modalDegrees.contains($0.modalDegree) })
    }

    @Test("Ineligible foundation behavior produces no articulation")
    func ineligibleBehaviorIsEmpty() {
        let fixture = fixture()
        for behavior in FoundationBehavior.allCases where behavior != .tunedPercussive {
            let articulations = ModalPercussionResolver.foundationArticulations(
                ensemble: fixture.ensemble,
                dna: fixture.dna,
                performance: fixture.performance,
                character: fixture.character,
                gesture: fixture.gesture,
                behavior: behavior
            )
            #expect(articulations.isEmpty)
        }

        let withoutToms = EnsembleContext(
            focusRole: .foundation,
            events: [
                EnsembleResolvedEvent(
                    voice: .bass, step: 3, intensity: 0.72, relocated: false
                ),
                EnsembleResolvedEvent(
                    voice: .rumble, step: 11, intensity: 0.46, relocated: false
                ),
            ],
            kickAnchors: [],
            intentionalPileup: false
        )
        #expect(ModalPercussionResolver.foundationArticulations(
            ensemble: withoutToms,
            dna: fixture.dna,
            performance: fixture.performance,
            character: fixture.character,
            gesture: fixture.gesture,
            behavior: .tunedPercussive
        ).isEmpty)
    }

    @Test("Malformed scalar input is contained by the articulation boundary")
    func malformedInputIsContained() {
        let nonFinite = ModalPercussionArticulation(
            scoreEventIndex: -4,
            step: -17,
            use: .foundationCompanion,
            modalIdentity: .dorian,
            modalDegree: 0,
            octave: 1,
            fundamentalHz: .nan,
            excitation: .nan,
            damping: .infinity,
            brightness: -.infinity,
            inharmonicity: .nan,
            eventIntensity: .nan,
            seed: 1,
            material: .bronzePlate,
            coupling: .nan
        )
        #expect(nonFinite.scoreEventIndex == 0)
        #expect(nonFinite.step == 15)
        #expect(nonFinite.fundamentalHz.isFinite)
        #expect(nonFinite.excitation.isFinite)
        #expect(nonFinite.damping.isFinite)
        #expect(nonFinite.brightness.isFinite)
        #expect(nonFinite.inharmonicity.isFinite)
        #expect(nonFinite.eventIntensity.isFinite)
        #expect(nonFinite.material == .bronzePlate)
        #expect(nonFinite.coupling == 0.18)
        #expect((48.0...196.0).contains(nonFinite.fundamentalHz))
        #expect((0.0...1.0).contains(nonFinite.excitation))
        #expect((0.0...1.0).contains(nonFinite.damping))
        #expect((0.0...1.0).contains(nonFinite.brightness))
        #expect((0.0...0.12).contains(nonFinite.inharmonicity))
        #expect((0.0...1.0).contains(nonFinite.eventIntensity))

        let below = malformed(fundamental: -1, material: -1)
        let above = malformed(fundamental: 1_000, material: 2)
        #expect(below.fundamentalHz == 48)
        #expect(below.excitation == 0)
        #expect(below.damping == 0)
        #expect(below.brightness == 0)
        #expect(below.inharmonicity == 0)
        #expect(below.eventIntensity == 0)
        #expect(below.coupling == 0)
        #expect(above.fundamentalHz == 196)
        #expect(above.excitation == 1)
        #expect(above.damping == 1)
        #expect(above.brightness == 1)
        #expect(above.inharmonicity == 0.12)
        #expect(above.eventIntensity == 1)
        #expect(above.coupling == 0.6)
    }

    private func resolve(
        _ fixture: Fixture,
        rhythmLanguage: LongHorizonRhythmLanguage = .fourOnFloor,
        materialArchitecture: LongHorizonTimbralArchitecture = .hybrid
    ) -> [ModalPercussionArticulation] {
        ModalPercussionResolver.foundationArticulations(
            ensemble: fixture.ensemble,
            dna: fixture.dna,
            performance: fixture.performance,
            character: fixture.character,
            gesture: fixture.gesture,
            behavior: .tunedPercussive,
            rhythmLanguage: rhythmLanguage,
            materialArchitecture: materialArchitecture
        )
    }

    private func fixture(seed: UInt64 = 48_291) -> Fixture {
        let scene = TechnoScene(
            intent: MusicalIntent(),
            seed: seed,
            bpm: AutonomousSessionDirector.bpm
        )
        let dna = SceneDNA(scene: scene)
        let performance = PerformanceBar(
            bar: 14,
            phrase: 1,
            localBar: 6,
            phraseLength: 8,
            section: .build,
            tension: 0.68,
            roles: [.foundation, .motif],
            transformations: [],
            signatureEvent: nil,
            eventSeed: 0xA11CE,
            accentContour: Array(repeating: 0.72, count: 16)
        )
        return Fixture(
            dna: dna,
            performance: performance,
            ensemble: EnsembleContext(
                focusRole: .foundation,
                events: [
                    EnsembleResolvedEvent(
                        voice: .kick, step: 0, intensity: 1, relocated: false
                    ),
                    EnsembleResolvedEvent(
                        voice: .tunedTom, step: 10, intensity: 0.58, relocated: false
                    ),
                    EnsembleResolvedEvent(
                        voice: .tunedTom, step: 14, intensity: 0.58, relocated: true
                    ),
                ],
                kickAnchors: [0],
                intentionalPileup: false
            ),
            character: .brokenSuspension,
            gesture: .structuralMarker
        )
    }

    private func singleDegreeFixture() -> Fixture? {
        for seed in UInt64(1)...2_048 {
            let candidate = fixture(seed: seed)
            if Set(candidate.dna.motif.degrees).count == 1 {
                return candidate
            }
        }
        return nil
    }

    private func malformed(
        fundamental: Double,
        material: Double
    ) -> ModalPercussionArticulation {
        ModalPercussionArticulation(
            scoreEventIndex: 0,
            step: 0,
            use: .foundationCompanion,
            modalIdentity: .aeolian,
            modalDegree: 3,
            octave: 1,
            fundamentalHz: fundamental,
            excitation: material,
            damping: material,
            brightness: material,
            inharmonicity: material,
            eventIntensity: material,
            seed: 2,
            coupling: material
        )
    }

    private struct Fixture {
        let dna: SceneDNA
        let performance: PerformanceBar
        let ensemble: EnsembleContext
        let character: PerformanceCharacter
        let gesture: ArrangementGesture
    }
}
