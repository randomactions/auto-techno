import AutoTechnoCore
import Testing

@Suite("Score-owned upper-note and timbre planning")
struct UpperTimbrePlanningTests {
    @Test("Upper-note values and semantic amounts stay inside their score bounds")
    func boundedValueContract() {
        let home = UpperTimbreIntent(kind: .home, amount: 0.91)
        let resonant = UpperTimbreIntent.resonantSequence(amount: 1.8)
        let detuned = UpperTimbreIntent.detunedMotion(amount: -0.4)

        #expect(home == .home)
        #expect(home.amount == 0)
        #expect(resonant.amount == 1)
        #expect(detuned.amount == 0)

        let lower = ResolvedUpperNote(
            role: .anchor,
            onsetStep: -8,
            durationInSteps: -2,
            startFrequencyRatio: 0,
            endFrequencyRatio: 40,
            velocity: 3,
            gate: .slide,
            timbreIntent: resonant
        )
        #expect(lower.onsetStep == 0)
        #expect(lower.durationInSteps == ResolvedUpperNote.minimumDurationInSteps)
        #expect(lower.startFrequencyRatio == ResolvedUpperNote.minimumFrequencyRatio)
        #expect(lower.endFrequencyRatio == ResolvedUpperNote.maximumFrequencyRatio)
        #expect(lower.velocity == 1)

        let upper = ResolvedUpperNote(
            role: .response,
            onsetStep: 28,
            durationInSteps: 80,
            startFrequencyRatio: 1,
            endFrequencyRatio: 1,
            velocity: -1,
            gate: .retrigger,
            timbreIntent: detuned
        )
        #expect(upper.onsetStep == 15)
        #expect(upper.durationInSteps == ResolvedUpperNote.maximumDurationInSteps)
        #expect(upper.velocity == 0)
    }

    @Test("Motion contrast and release put the resonant sequence only on the dominant motif")
    func resonantSequenceSelection() {
        guard let (scene, dna) = distinctMotifScene() else {
            Issue.record("Expected a deterministic scene with two distinct motif degrees")
            return
        }

        for kind in [AutonomousPhraseKind.contrast, .energyRelease] {
            let resolved = makeResolvedBar(
                kind: kind,
                chapter: .motion,
                events: standardUpperEvents
            )
            let first = SynthPerformancePlan(
                scene: scene, dna: dna, kind: kind, resolvedBars: [resolved]
            )
            let second = SynthPerformancePlan(
                scene: scene, dna: dna, kind: kind, resolvedBars: [resolved]
            )
            #expect(first == second)

            let bar = first.bars[0]
            let anchors = bar.upperNotes(for: .anchor)
            #expect(anchors.count == 2)
            #expect(anchors.map(\.onsetStep) == [2, 10])
            #expect(bar.upperNotes(for: .shadow).map(\.onsetStep) == [2, 10])
            #expect(bar.upperNotes(for: .response).map(\.onsetStep) == [7])
            #expect(bar.upperNotes(for: .atmosphere).map(\.onsetStep) == [4])
            #expect(bar.upperNotes(for: .transition).map(\.onsetStep) == [15])
            #expect(anchors.allSatisfy {
                $0.timbreIntent.kind == .resonantSequence && $0.timbreIntent.amount > 0
            })
            #expect(bar.upperNotes.filter {
                $0.timbreIntent.kind == .resonantSequence
            }.allSatisfy { $0.role == .anchor })
            #expect(anchors.filter { $0.gate == .slide }.count == 1)
            #expect(bar.upperNotes.filter { $0.gate == .slide }.count == 1)
            if let slide = anchors.firstIndex(where: { $0.gate == .slide }), slide > 0 {
                #expect(anchors[slide - 1].durationInSteps >=
                        Double(anchors[slide].onsetStep - anchors[slide - 1].onsetStep))
            }
            #expect(bar.upperNotes.allSatisfy(noteIsBounded))
        }

        let threeNoteBar = SynthPerformancePlan(
            scene: scene,
            dna: dna,
            kind: .contrast,
            resolvedBars: [makeResolvedBar(
                kind: .contrast,
                chapter: .motion,
                events: standardUpperEvents + [EnsembleResolvedEvent(
                    voice: .motif, step: 14, intensity: 0.70, relocated: false
                )]
            )]
        ).bars[0]
        #expect(threeNoteBar.upperNotes(for: .anchor).count == 3)
        #expect(threeNoteBar.upperNotes.filter { $0.gate == .slide }.count == 1)

        let singleMotif = standardUpperEvents.filter {
            $0.voice != .motif || $0.step == 2
        }
        let fallback = SynthPerformancePlan(
            scene: scene,
            dna: dna,
            kind: .contrast,
            resolvedBars: [makeResolvedBar(
                kind: .contrast, chapter: .motion, events: singleMotif
            )]
        ).bars[0]
        #expect(fallback.upperNotes(for: .anchor).count == 1)
        #expect(fallback.upperNotes.allSatisfy { $0.timbreIntent == .home })
        #expect(fallback.upperNotes.allSatisfy { $0.gate == .retrigger })
    }

    @Test("Tone chapters put detuned motion only on shadow and response notes")
    func detunedMotionSelection() {
        guard let (scene, dna) = distinctMotifScene() else {
            Issue.record("Expected a deterministic upper-voice scene")
            return
        }
        let plan = SynthPerformancePlan(
            scene: scene,
            dna: dna,
            kind: .contrast,
            resolvedBars: [makeResolvedBar(
                kind: .contrast, chapter: .tone, events: standardUpperEvents
            )]
        )
        let bar = plan.bars[0]
        let detuned = bar.upperNotes.filter { $0.timbreIntent.kind == .detunedMotion }

        #expect(!bar.upperNotes(for: .shadow).isEmpty)
        #expect(!bar.upperNotes(for: .response).isEmpty)
        #expect(bar.upperNotes(for: .anchor).map(\.onsetStep) == [2, 10])
        #expect(bar.upperNotes(for: .shadow).map(\.onsetStep) == [2, 10])
        #expect(bar.upperNotes(for: .response).map(\.onsetStep) == [7])
        #expect(!detuned.isEmpty)
        #expect(detuned.allSatisfy { $0.role == .shadow || $0.role == .response })
        #expect(bar.upperNotes.filter {
            $0.role == .shadow || $0.role == .response
        }.allSatisfy { $0.timbreIntent.kind == .detunedMotion })
        #expect(bar.upperNotes.filter {
            $0.role != .shadow && $0.role != .response
        }.allSatisfy { $0.timbreIntent == .home })
        #expect(bar.upperNotes.allSatisfy { $0.gate == .retrigger })
    }

    @Test("Identity, major-break, and ineligible chapters return to the home timbre")
    func protectedHomeSelection() {
        guard let (scene, dna) = distinctMotifScene() else {
            Issue.record("Expected a deterministic upper-voice scene")
            return
        }
        let cases: [(AutonomousPhraseKind, InterlockChapter)] = [
            (.identityReturn, .motion),
            (.majorBreak, .tone),
            (.lock, .home),
            (.lock, .motion),
            (.contrast, .breath),
        ]

        for (kind, chapter) in cases {
            let bar = SynthPerformancePlan(
                scene: scene,
                dna: dna,
                kind: kind,
                resolvedBars: [makeResolvedBar(
                    kind: kind, chapter: chapter, events: standardUpperEvents
                )]
            ).bars[0]
            #expect(!bar.upperNotes.isEmpty)
            #expect(bar.upperNotes(for: .anchor).map(\.onsetStep) == [2, 10])
            #expect(bar.upperNotes(for: .atmosphere).map(\.onsetStep) == [4])
            #expect(bar.upperNotes.allSatisfy { $0.timbreIntent == .home })
            #expect(bar.upperNotes.allSatisfy { $0.gate == .retrigger })
        }
    }

    @Test("A suspended breakdown retains only its resolved distant transition carrier")
    func suspendedTransitionCarrier() {
        guard let (scene, dna) = distinctMotifScene() else {
            Issue.record("Expected a deterministic upper-voice scene")
            return
        }
        let carrierStep = 13
        let events = standardUpperEvents + [
            EnsembleResolvedEvent(
                voice: .transition, step: carrierStep, intensity: 0.82, relocated: false
            ),
        ]
        let spatial = SpatialContrastArticulation(
            depthPosition: .distant,
            carrierVoice: .transition,
            carrierStep: carrierStep,
            dryScale: 0.72,
            reverbSend: 0.30,
            highPassHz: 300,
            lowPassHz: 4_200
        )
        let bar = SynthPerformancePlan(
            scene: scene,
            dna: dna,
            kind: .majorBreak,
            resolvedBars: [makeResolvedBar(
                kind: .majorBreak,
                chapter: .tone,
                events: events,
                spatialContrast: spatial
            )]
        ).bars[0]

        #expect(bar.gesture == .suspend)
        #expect(bar.upperNotes(for: .transition).map(\.onsetStep) == [carrierStep])
        #expect(bar.upperNotes(for: .transition).allSatisfy {
            $0.timbreIntent == .home && $0.gate == .retrigger
        })

        let foreground = SynthPerformancePlan(
            scene: scene,
            dna: dna,
            kind: .majorBreak,
            resolvedBars: [makeResolvedBar(
                kind: .majorBreak,
                chapter: .tone,
                events: events,
                spatialContrast: .foreground
            )]
        ).bars[0]
        #expect(foreground.upperNotes(for: .transition).isEmpty)
    }

    @Test("A conservative candidate forces the authored home articulation")
    func conservativeFallbackHome() {
        guard let (scene, dna) = distinctMotifScene() else {
            Issue.record("Expected a deterministic upper-voice scene")
            return
        }
        let resolved = makeResolvedBar(
            kind: .contrast,
            chapter: .tone,
            events: standardUpperEvents
        )
        let exploratory = SynthPerformancePlan(
            scene: scene,
            dna: dna,
            kind: .contrast,
            resolvedBars: [resolved]
        ).bars[0]
        let fallback = SynthPerformancePlan(
            scene: scene,
            dna: dna,
            kind: .contrast,
            resolvedBars: [resolved],
            conservative: true
        ).bars[0]

        #expect(exploratory.upperNotes.contains {
            $0.timbreIntent.kind == .detunedMotion
        })
        #expect(fallback.upperNotes.allSatisfy { $0.timbreIntent == .home })
        #expect(fallback.upperNotes.allSatisfy { $0.gate == .retrigger })
    }

    private var standardUpperEvents: [EnsembleResolvedEvent] {
        [
            EnsembleResolvedEvent(voice: .motif, step: 2, intensity: 0.82, relocated: false),
            EnsembleResolvedEvent(voice: .motif, step: 10, intensity: 0.76, relocated: false),
            EnsembleResolvedEvent(voice: .response, step: 7, intensity: 0.68, relocated: false),
            EnsembleResolvedEvent(voice: .atmosphere, step: 4, intensity: 0.58,
                                  relocated: false),
            EnsembleResolvedEvent(voice: .transition, step: 15, intensity: 0.70,
                                  relocated: false),
        ]
    }

    private func distinctMotifScene() -> (TechnoScene, SceneDNA)? {
        let intent = MusicalIntent(values: [
            .groove: 0.90,
            .syncopation: 0.75,
            .darkness: 0.76,
            .hypnosis: 0.82,
            .atmosphere: 0.62,
            .drone: 0.54,
            .melodicity: 0.78,
            .synthPresence: 0.74,
            .noteActivity: 1,
        ])
        for seed in UInt64(1)...128 {
            let scene = TechnoScene(intent: intent, seed: seed, bpm: 130)
            let dna = SceneDNA(scene: scene)
            if dna.motif.degrees.count >= 2, dna.motif.degrees[0] != dna.motif.degrees[1] {
                return (scene, dna)
            }
        }
        return nil
    }

    private func makeResolvedBar(
        kind: AutonomousPhraseKind,
        chapter: InterlockChapter,
        events: [EnsembleResolvedEvent],
        spatialContrast: SpatialContrastArticulation = .foreground
    ) -> ResolvedPerformanceBar {
        let section: SectionKind = switch kind {
        case .lock: .groove
        case .contrast: .build
        case .majorBreak: .breakdown
        case .energyRelease, .identityReturn: .returnSection
        }
        let gesture: ArrangementGesture = switch kind {
        case .contrast: .turnaround
        case .majorBreak, .energyRelease, .identityReturn: .structuralMarker
        case .lock: .steady
        }
        return ResolvedPerformanceBar(
            performance: PerformanceBar(
                bar: 7,
                phrase: 1,
                localBar: 3,
                phraseLength: 8,
                section: section,
                tension: 0.72,
                roles: [.motif, .response, .atmosphere, .transition],
                transformations: [],
                signatureEvent: nil,
                eventSeed: 0xA11CE,
                accentContour: (0..<16).map { $0.isMultiple(of: 4) ? 1 : 0.42 }
            ),
            ensemble: EnsembleContext(
                focusRole: .motif,
                events: events,
                kickAnchors: [0, 4, 8, 12],
                intentionalPileup: false
            ),
            arrangementGesture: gesture,
            percussionGear: .contrast,
            foundationCompanion: .bass,
            pulseEchoEnabled: false,
            interlockChapter: chapter,
            spatialContrast: spatialContrast
        )
    }

    private func noteIsBounded(_ note: ResolvedUpperNote) -> Bool {
        (0...15).contains(note.onsetStep) &&
            note.durationInSteps >= ResolvedUpperNote.minimumDurationInSteps &&
            note.durationInSteps <= ResolvedUpperNote.maximumDurationInSteps &&
            note.startFrequencyRatio >= ResolvedUpperNote.minimumFrequencyRatio &&
            note.startFrequencyRatio <= ResolvedUpperNote.maximumFrequencyRatio &&
            note.endFrequencyRatio >= ResolvedUpperNote.minimumFrequencyRatio &&
            note.endFrequencyRatio <= ResolvedUpperNote.maximumFrequencyRatio &&
            note.timingOffsetInSteps.isFinite &&
            (0...ResolvedUpperNote.maximumTimingOffsetInSteps)
                .contains(note.timingOffsetInSteps) &&
            (0...1).contains(note.velocity) &&
            (0...1).contains(note.timbreIntent.amount)
    }
}
