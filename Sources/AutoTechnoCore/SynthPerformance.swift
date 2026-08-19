import Foundation

/// Listener-scale movement of the authored synth world. The DSP layer derives
/// oscillator, filter, distortion, and delay values from this intention.
package enum SynthGesture: String, CaseIterable, Sendable {
    case reveal
    case interlock
    case corrode
    case suspend
    case release
}

package enum SynthRole: String, CaseIterable, Sendable {
    case anchor
    case shadow
    case atmosphere
    case response
    case transition
}

/// A score-owned request for one bounded reinterpretation of the authored
/// upper voice. The kind is semantic; DSP remains responsible for translating
/// it into a stable oscillator, filter, and modulation implementation.
package struct UpperTimbreIntent: Equatable, Sendable {
    package enum Kind: String, CaseIterable, Sendable {
        case home
        case resonantSequence
        case detunedMotion
    }

    package let kind: Kind
    package let amount: Double

    package init(kind: Kind, amount: Double) {
        self.kind = kind
        self.amount = kind == .home ? 0 : min(1, max(0, amount))
    }

    package static let home = UpperTimbreIntent(kind: .home, amount: 0)

    package static func resonantSequence(amount: Double) -> UpperTimbreIntent {
        UpperTimbreIntent(kind: .resonantSequence, amount: amount)
    }

    package static func detunedMotion(amount: Double) -> UpperTimbreIntent {
        UpperTimbreIntent(kind: .detunedMotion, amount: amount)
    }
}

/// Envelope behavior at a resolved note boundary. A slide continues the
/// previous note's pitch and envelope into this note; every other note starts a
/// fresh envelope.
package enum UpperNoteGate: String, CaseIterable, Sendable {
    case retrigger
    case slide
}

/// Durable envelope meaning for an already-resolved upper note. `home` keeps
/// the patch envelope exact; `sustainedWash` asks the existing Tonal Motion
/// voice to let the same articulated note occupy a release boundary at a
/// larger temporal scale. DSP owns the replaceable numeric realization.
package enum UpperEnvelopeRelation: String, CaseIterable, Sendable {
    case home
    case sustainedWash
}

/// The complete score-owned pitch and articulation request for one upper note.
/// Start and end ratios are requested trajectory anchors relative to
/// `SynthWorldDNA.rootFrequency`. DSP records the continuation-dependent
/// audible start/end frequencies separately, so the continuing home glide remains
/// observable instead of being misrepresented as a score decision.
package struct ResolvedUpperNote: Equatable, Sendable {
    package static let minimumDurationInSteps = 1.0 / 16.0
    package static let maximumDurationInSteps = 16.0
    package static let minimumFrequencyRatio = 0.125
    package static let maximumFrequencyRatio = 8.0
    package static let maximumTimingOffsetInSteps = 0.12

    package let role: SynthRole
    package let onsetStep: Int
    package let durationInSteps: Double
    package let startFrequencyRatio: Double
    package let endFrequencyRatio: Double
    package let velocity: Double
    package let gate: UpperNoteGate
    package let timbreIntent: UpperTimbreIntent
    package let envelopeRelation: UpperEnvelopeRelation
    package let spectralReveal: UpperSpectralRevealArticulation
    /// A score-owned positive onset displacement measured in sixteenth-note
    /// steps. Duration remains independent so delaying a note never shortens
    /// its requested gate.
    package let timingOffsetInSteps: Double
    package let instrument: InstrumentAssignment

    package init(role: SynthRole, onsetStep: Int, durationInSteps: Double,
                 startFrequencyRatio: Double, endFrequencyRatio: Double,
                 velocity: Double, gate: UpperNoteGate,
                 timbreIntent: UpperTimbreIntent,
                 envelopeRelation: UpperEnvelopeRelation = .home,
                 spectralReveal: UpperSpectralRevealArticulation = .home,
                 timingOffsetInSteps: Double = 0,
                 instrument: InstrumentAssignment? = nil) {
        self.role = role
        self.onsetStep = min(15, max(0, onsetStep))
        self.durationInSteps = min(
            Self.maximumDurationInSteps,
            max(Self.minimumDurationInSteps, durationInSteps)
        )
        self.startFrequencyRatio = min(
            Self.maximumFrequencyRatio,
            max(Self.minimumFrequencyRatio, startFrequencyRatio)
        )
        self.endFrequencyRatio = min(
            Self.maximumFrequencyRatio,
            max(Self.minimumFrequencyRatio, endFrequencyRatio)
        )
        self.velocity = min(1, max(0, velocity))
        self.gate = gate
        self.timbreIntent = timbreIntent
        self.envelopeRelation = envelopeRelation
        self.spectralReveal = spectralReveal
        self.timingOffsetInSteps = timingOffsetInSteps.isFinite
            ? min(Self.maximumTimingOffsetInSteps, max(0, timingOffsetInSteps))
            : 0
        self.instrument = instrument ?? InstrumentPalette.safeUpper(role: role)
    }

    package func withTimingOffsetInSteps(_ value: Double) -> ResolvedUpperNote {
        ResolvedUpperNote(
            role: role,
            onsetStep: onsetStep,
            durationInSteps: durationInSteps,
            startFrequencyRatio: startFrequencyRatio,
            endFrequencyRatio: endFrequencyRatio,
            velocity: velocity,
            gate: gate,
            timbreIntent: timbreIntent,
            envelopeRelation: envelopeRelation,
            spectralReveal: spectralReveal,
            timingOffsetInSteps: value,
            instrument: instrument
        )
    }

    package func withSpectralReveal(
        _ articulation: UpperSpectralRevealArticulation
    ) -> ResolvedUpperNote {
        ResolvedUpperNote(
            role: role,
            onsetStep: onsetStep,
            durationInSteps: durationInSteps,
            startFrequencyRatio: startFrequencyRatio,
            endFrequencyRatio: endFrequencyRatio,
            velocity: velocity,
            gate: gate,
            timbreIntent: timbreIntent,
            envelopeRelation: envelopeRelation,
            spectralReveal: articulation,
            timingOffsetInSteps: timingOffsetInSteps,
            instrument: instrument
        )
    }
}

/// The one upper-voice characteristic allowed to come forward during a
/// sixteen-bar chapter. Chapters reinterpret the same instrument; they never
/// replace its pitch cell or timbral fingerprint.
package enum InterlockChapter: String, CaseIterable, Sendable {
    case home
    case breath
    case tone
    case motion
    case memory
}

/// One canonical owner for deliberate upper-note placement. Relations describe
/// musical intent; exact frame scheduling remains renderer-owned.
package enum UpperTimingRelation: String, CaseIterable, Sendable {
    case aligned
    case harmonicCascade
    case leadPerformance
}

package enum RelationalFollowerStage: Int, CaseIterable, Sendable {
    case anchor
    case inhale
    case open
    case spill
    case withdraw
}

/// A true daisy-chain phase: the three-step driver advances the five-stage
/// follower only when it wraps. The phase is intentionally reset by the
/// global sixteen-bar macro grid rather than by adaptive phrase boundaries.
package struct RelationalCyclePhase: Equatable, Sendable {
    package let macroStep: Int
    package let driverPhase: Int
    package let followerStage: RelationalFollowerStage

    package init(macroStep: Int) {
        let bounded = ((macroStep % 256) + 256) % 256
        self.macroStep = bounded
        driverPhase = bounded % 3
        followerStage = RelationalFollowerStage(rawValue: (bounded / 3) % 5) ?? .anchor
    }
}

/// Fully resolved, bounded performance scalars consumed by the authored upper
/// voice. They scale the stable motif fingerprint instead of selecting a new
/// instrument identity.
package struct RelationalArticulation: Equatable, Sendable {
    package let chapter: InterlockChapter
    package let phase: RelationalCyclePhase
    package let velocityScale: Double
    package let attackScale: Double
    package let decayScale: Double
    package let spectralScale: Double
    package let spectralAperture: Double
    package let anchorSpectralScale: Double
    package let complementarySpectralScale: Double
    package let bandPassBlend: Double
    package let glideTimeScale: Double
    package let pulseEchoSend: Double

    package init(chapter: InterlockChapter, phase: RelationalCyclePhase,
                 pulseEchoEligible: Bool,
                 spectralSculptureEnabled: Bool = true) {
        let stage = phase.followerStage.rawValue
        let driverVelocity = [1.00, 0.94, 0.86][phase.driverPhase]
        let followerVelocity = [1.00, 0.94, 1.04, 1.08, 0.84][stage]
        let followerSpectralScale = [1.00, 0.92, 1.06, 1.10, 0.88][stage]
        let toneSculptureActive = chapter == .tone && spectralSculptureEnabled
        let aperture: Double
        if toneSculptureActive, phase.macroStep != 0, phase.macroStep != 255 {
            let progress = Double(phase.macroStep) / 255
            let sine = sin(.pi * progress)
            aperture = sine * sine
        } else {
            aperture = 0
        }
        let anchorScale = toneSculptureActive
            ? 1 + (followerSpectralScale - 1) * aperture : 1
        let complementaryScale = toneSculptureActive
            ? 1 - (followerSpectralScale - 1) * aperture * 0.65 : 1

        self.chapter = chapter
        self.phase = phase
        velocityScale = driverVelocity * followerVelocity
        attackScale = chapter == .breath
            ? [1.00, 1.55, 0.88, 0.78, 1.12][stage] : 1
        decayScale = chapter == .breath
            ? [1.00, 0.90, 1.18, 1.32, 0.72][stage] : 1
        spectralScale = anchorScale
        spectralAperture = aperture
        anchorSpectralScale = anchorScale
        complementarySpectralScale = complementaryScale
        bandPassBlend = toneSculptureActive ? 0.15 * aperture : 0
        glideTimeScale = chapter == .motion
            ? [1.00, 1.10, 1.15, 1.35, 0.82][stage] : 1
        pulseEchoSend = chapter == .memory && pulseEchoEligible
            ? [0.0, 0.0, 0.10, 0.22, 0.0][stage] : 0
    }

    package static let neutral = RelationalArticulation(
        chapter: .home,
        phase: RelationalCyclePhase(macroStep: 0),
        pulseEchoEligible: false
    )
}

/// Score-owned control for the existing pulse-echo return. The source remains
/// truthful even when the gesture is ineligible, while the applied amount is
/// forced to an exact neutral value outside its bounded musical context. A
/// source beginning after step 12 cannot produce a 3/16 return in this bar, so
/// late-only material remains neutral rather than changing a following tail.
package struct PulseEchoTextureArticulation: Equatable, Sendable {
    package static let maximumAppliedAmount = 0.55
    package static let latestDrivenOnsetStep = 12

    package let machineTexture: Double
    package let earliestPulseEchoOnsetStep: Int?
    package let driveEligible: Bool
    package let appliedAmount: Double

    package init(machineTexture: Double, enabled: Bool,
                 earliestPulseEchoOnsetStep: Int?) {
        let boundedTexture = machineTexture.isFinite
            ? min(1, max(0, machineTexture)) : 0
        let boundedOnset = earliestPulseEchoOnsetStep.flatMap {
            (0..<16).contains($0) ? $0 : nil
        }
        self.machineTexture = boundedTexture
        self.earliestPulseEchoOnsetStep = boundedOnset
        driveEligible = enabled && boundedOnset.map {
            $0 <= Self.latestDrivenOnsetStep
        } == true
        appliedAmount = driveEligible
            ? min(Self.maximumAppliedAmount, boundedTexture) : 0
    }

    package static let neutral = PulseEchoTextureArticulation(
        machineTexture: 0,
        enabled: false,
        earliestPulseEchoOnsetStep: nil
    )
}

/// Bounded long-form memory. Only the current chapter and the two chapters
/// before it are retained, so an indefinitely running session does not grow
/// state.
package struct InterlockEvolutionState: Equatable, Sendable {
    package private(set) var currentChapter: InterlockChapter
    package private(set) var previousChapters: [InterlockChapter]
    package private(set) var macroIndex: Int
    package private(set) var macrosSinceHome: Int

    package init(currentChapter: InterlockChapter = .home,
                 previousChapters: [InterlockChapter] = [],
                 macroIndex: Int = 0, macrosSinceHome: Int = 0) {
        self.currentChapter = currentChapter
        self.previousChapters = Array(previousChapters.suffix(2))
        self.macroIndex = max(0, macroIndex)
        self.macrosSinceHome = max(0, macrosSinceHome)
    }

    package func advancing(for kind: AutonomousPhraseKind,
                           entropy: UInt64) -> InterlockEvolutionState {
        let forceHome = kind == .identityReturn || macrosSinceHome >= 4
        let selected: InterlockChapter
        if forceHome {
            selected = .home
        } else {
            let preferred: [InterlockChapter]
            switch kind {
            case .lock: preferred = [.breath, .tone]
            case .contrast: preferred = [.tone, .motion]
            case .majorBreak: preferred = [.memory, .breath]
            case .energyRelease: preferred = [.motion, .breath]
            case .identityReturn: preferred = [.home]
            }
            let nonHome: [InterlockChapter] = [.breath, .tone, .motion, .memory]
            let recent = Set(previousChapters + [currentChapter])
            let unusedPreferred = preferred.filter { !recent.contains($0) }
            let unseenNonHome = nonHome.filter { !recent.contains($0) }
            let choices = !unusedPreferred.isEmpty ? unusedPreferred
                : (!unseenNonHome.isEmpty ? unseenNonHome : nonHome)
            selected = choices[Int(entropy % UInt64(choices.count))]
        }
        return InterlockEvolutionState(
            currentChapter: selected,
            previousChapters: previousChapters + [currentChapter],
            macroIndex: macroIndex + 1,
            macrosSinceHome: selected == .home ? 0 : macrosSinceHome + 1
        )
    }
}

/// A seed-stable description of the dominant motif's audible identity. Phrase
/// transformations may move or fragment the motif without replacing this
/// envelope, modulation family, or spectral home.
package struct MotifTimbreFingerprint: Equatable, Sendable {
    package let envelopeFamily: Int
    package let modulationFamily: Int
    package let spectralRegion: Int

    package init(envelopeFamily: Int, modulationFamily: Int, spectralRegion: Int) {
        self.envelopeFamily = min(2, max(0, envelopeFamily))
        self.modulationFamily = min(2, max(0, modulationFamily))
        self.spectralRegion = min(2, max(0, spectralRegion))
    }
}

/// Stable musical identity shared by every synth role in a scene.
package struct SynthWorldDNA: Equatable, Sendable {
    package let sceneSeed: UInt64
    package let variation: Int
    package let rootFrequency: Double
    package let shadowInterval: Int
    package let responseInterval: Int
    package let motifFingerprint: MotifTimbreFingerprint

    package init(scene: TechnoScene, dna: SceneDNA) {
        sceneSeed = scene.seed
        variation = dna.timbralFamily
        rootFrequency = 65.41 * pow(2, Double(dna.tonalCenter) / 12)
        let shadowIntervals: [Int]
        let responseIntervals: [Int]
        switch dna.modalIdentity {
        case .phrygian:
            shadowIntervals = [1, 3, 7, 12]
            responseIntervals = [7, 12, 13, 15]
        case .aeolian:
            shadowIntervals = [3, 5, 7, 10]
            responseIntervals = [7, 10, 12, 15]
        case .dorian:
            shadowIntervals = [3, 5, 7, 9]
            responseIntervals = [7, 9, 12, 15]
        }
        shadowInterval = shadowIntervals[dna.timbralFamily % shadowIntervals.count]
        responseInterval = responseIntervals[dna.timbralFamily % responseIntervals.count]
        motifFingerprint = MotifTimbreFingerprint(
            envelopeFamily: Int(SceneDNA.derivedSeed(
                scene: scene.seed, domain: 0xE17E10, index: dna.timbralFamily
            ) % 3),
            modulationFamily: Int(SceneDNA.derivedSeed(
                scene: scene.seed, domain: 0xA40D, index: dna.timbralFamily
            ) % 3),
            spectralRegion: Int(SceneDNA.derivedSeed(
                scene: scene.seed, domain: 0x5EEC72A1, index: dna.timbralFamily
            ) % 3)
        )
    }
}

package struct SynthPerformanceBar: Equatable, Sendable {
    package let bar: Int
    package let gesture: SynthGesture
    package let mutationAmount: Double
    package let foundationInstrument: InstrumentAssignment
    package let relationalSteps: [RelationalArticulation]
    package let upperNotes: [ResolvedUpperNote]
    package let composition: PhraseCompositionBar
    package let upperTimingRelation: UpperTimingRelation
    package let pulseEchoTextureArticulation: PulseEchoTextureArticulation
    /// Eligibility before an attempt-local home-timbre correction. The
    /// selected note carries the active relation; a correction retains this
    /// fact while resolving every relation to exact home.
    package let tonalEnvelopeExpansionEligible: Bool
    /// Eligibility before an attempt-local home correction. Applied notes can
    /// still be exact home while retaining this causal score fact.
    package let spectralRevealEligible: Bool
    /// Attempt-local correction ownership. This is kept separate from
    /// eligibility so a corrected bar can prove the feature would normally
    /// have been active while forcing any incoming long release home before
    /// its first onset.
    package let forceHomeUpperTimbre: Bool

    package init(bar: Int, gesture: SynthGesture, mutationAmount: Double,
                foundationInstrument: InstrumentAssignment = InstrumentPalette.safeFoundation(),
                relationalSteps: [RelationalArticulation],
                upperNotes: [ResolvedUpperNote],
                composition: PhraseCompositionBar? = nil,
                upperTimingRelation: UpperTimingRelation = .aligned,
                pulseEchoTextureArticulation: PulseEchoTextureArticulation = .neutral,
                tonalEnvelopeExpansionEligible: Bool = false,
                spectralRevealEligible: Bool = false,
                forceHomeUpperTimbre: Bool = false) {
        self.bar = bar
        self.gesture = gesture
        self.mutationAmount = min(1, max(0, mutationAmount))
        self.foundationInstrument = foundationInstrument.isValid
            ? foundationInstrument : InstrumentPalette.safeFoundation()
        self.relationalSteps = relationalSteps.count == 16
            ? relationalSteps : Array(repeating: .neutral, count: 16)
        self.upperNotes = upperNotes
        self.composition = composition ?? .neutral(bar: bar)
        self.upperTimingRelation = upperTimingRelation
        self.pulseEchoTextureArticulation = pulseEchoTextureArticulation
        self.tonalEnvelopeExpansionEligible = tonalEnvelopeExpansionEligible
        self.spectralRevealEligible = spectralRevealEligible
        self.forceHomeUpperTimbre = forceHomeUpperTimbre
    }

    package func articulation(at step: Int) -> RelationalArticulation {
        relationalSteps[((step % 16) + 16) % 16]
    }

    package func upperNotes(for role: SynthRole) -> [ResolvedUpperNote] {
        upperNotes.filter { $0.role == role }
    }
}

/// A deterministic upper-voice score. Its relational phase continues across
/// phrase and bar boundaries, then deliberately realigns on the global macro
/// grid. Foundation and percussion voices are not part of this plan.
package struct SynthPerformancePlan: Equatable, Sendable {
    package let world: SynthWorldDNA
    package let kind: AutonomousPhraseKind
    package let homeTimbreCorrection: Bool
    package let bars: [SynthPerformanceBar]

    package init(scene: TechnoScene, dna: SceneDNA, kind: AutonomousPhraseKind,
                 resolvedBars: [ResolvedPerformanceBar],
                 forceHomeUpperTimbre: Bool = false,
                 compositionBars suppliedComposition: [PhraseCompositionBar]? = nil) {
        let synthWorld = SynthWorldDNA(scene: scene, dna: dna)
        let authoredCompositionBars = suppliedComposition ??
            PhraseCompositionResolver.resolve(
                scene: scene,
                dna: dna,
                kind: kind,
                resolvedBars: resolvedBars
            )
        let compositionBars = forceHomeUpperTimbre
            ? resolvedBars.map { PhraseCompositionBar.neutral(bar: $0.performance.bar) }
            : authoredCompositionBars
        let synthBars = resolvedBars.enumerated().map { index, resolved in
            let performanceBar = resolved.performance
            let composition = compositionBars.indices.contains(index)
                ? compositionBars[index] : .neutral(bar: performanceBar.bar)
            let gesture = SynthPerformancePlan.gesture(for: performanceBar)
            let mutation = SynthPerformancePlan.mutation(for: gesture, tension: performanceBar.tension)
            let macroBar = ((performanceBar.bar % 16) + 16) % 16
            let hasRelationalUpperMaterial = resolved.ensemble.events.contains {
                $0.voice == .motif || $0.voice == .response
            }
            let spectralSculptureEnabled = kind != .identityReturn &&
                kind != .majorBreak && hasRelationalUpperMaterial
            let relationalSteps = (0..<16).map { step in
                RelationalArticulation(
                    chapter: resolved.interlockChapter,
                    phase: RelationalCyclePhase(macroStep: macroBar * 16 + step),
                    pulseEchoEligible: resolved.pulseEchoEnabled,
                    spectralSculptureEnabled: spectralSculptureEnabled
                )
            }
            let upperResolution = SynthPerformancePlan.resolvedUpperNotes(
                scene: scene,
                dna: dna,
                kind: kind,
                world: synthWorld,
                resolved: resolved,
                gesture: gesture,
                mutationAmount: mutation,
                forceHomeUpperTimbre: forceHomeUpperTimbre,
                relationalSteps: relationalSteps,
                composition: composition
            )
            let upperNotes = upperResolution.notes
            let eligibilityNotes: [ResolvedUpperNote]
            if forceHomeUpperTimbre {
                let authoredComposition = authoredCompositionBars.indices.contains(index)
                    ? authoredCompositionBars[index]
                    : .neutral(bar: performanceBar.bar)
                eligibilityNotes = SynthPerformancePlan.resolvedUpperNotes(
                    scene: scene,
                    dna: dna,
                    kind: kind,
                    world: synthWorld,
                    resolved: resolved,
                    gesture: gesture,
                    mutationAmount: mutation,
                    forceHomeUpperTimbre: false,
                    relationalSteps: relationalSteps,
                    composition: authoredComposition
                ).notes
            } else {
                eligibilityNotes = upperNotes
            }
            let spectralRevealEligible = eligibilityNotes.contains { note in
                note.role == .anchor &&
                    UpperSpectralRevealResolver.articulation(
                        role: note.role,
                        narrative: resolved.narrative,
                        phraseKind: kind,
                        forceHome: false,
                        step: note.onsetStep
                    ).relation == .emerging
            }
            let earliestPulseEchoOnsetStep = upperNotes
                .filter { $0.instrument.effects.contains(.pulseEcho) }
                .map { $0.onsetStep }
                .min()
            let pulseEchoTextureEnabled = resolved.interlockChapter == .memory &&
                resolved.pulseEchoEnabled &&
                earliestPulseEchoOnsetStep != nil &&
                !forceHomeUpperTimbre &&
                kind != .identityReturn &&
                kind != .majorBreak
            return SynthPerformanceBar(
                bar: performanceBar.bar,
                gesture: gesture,
                mutationAmount: mutation,
                foundationInstrument: InstrumentPalette.resolveFoundation(
                    world: synthWorld,
                    kind: kind,
                    gesture: gesture,
                    mutationAmount: mutation,
                    foundationBehavior: resolved.foundationBehavior
                ),
                relationalSteps: relationalSteps,
                upperNotes: upperNotes,
                composition: composition,
                upperTimingRelation: upperResolution.timingRelation,
                pulseEchoTextureArticulation: PulseEchoTextureArticulation(
                    machineTexture: scene.machineTexture,
                    enabled: pulseEchoTextureEnabled,
                    earliestPulseEchoOnsetStep: earliestPulseEchoOnsetStep
                ),
                tonalEnvelopeExpansionEligible:
                    upperResolution.tonalEnvelopeExpansionEligible,
                spectralRevealEligible: spectralRevealEligible,
                forceHomeUpperTimbre: forceHomeUpperTimbre
            )
        }
        world = synthWorld
        self.kind = kind
        homeTimbreCorrection = forceHomeUpperTimbre
        bars = synthBars
    }

    /// A deterministic sixteen-bar align-spread-realign aperture. Bars 0 and
    /// 15 are exact zero; distance to the nearest endpoint rises linearly over
    /// seven bars, giving bars 7 and 8 the exact unit plateau before reversal.
    package static func upperTimingAperture(absoluteBar: Int) -> Double {
        let macroBar = ((absoluteBar % 16) + 16) % 16
        guard macroBar != 0, macroBar != 15 else { return 0 }
        return min(1, Double(min(macroBar, 15 - macroBar)) / 7)
    }

    package static func upperTimingOffsetInSteps(for role: SynthRole,
                                                 absoluteBar: Int,
                                                 enabled: Bool) -> Double {
        guard enabled else { return 0 }
        let fullDepth = ResolvedUpperNote.maximumTimingOffsetInSteps *
            upperTimingAperture(absoluteBar: absoluteBar)
        switch role {
        case .shadow: return fullDepth * 0.5
        case .response: return fullDepth
        case .anchor, .atmosphere, .transition: return 0
        }
    }

    package static func upperTimingEligible(notes: [ResolvedUpperNote],
                                            chapter: InterlockChapter,
                                            variationEnabled: Bool) -> Bool {
        variationEnabled && chapter == .breath &&
            notes.contains { $0.role == .anchor } &&
            notes.contains { $0.role == .shadow || $0.role == .response }
    }

    private static func gesture(for bar: PerformanceBar) -> SynthGesture {
        switch bar.section {
        case .groove:
            return bar.phrase == 0 && bar.localBar < max(2, bar.phraseLength / 2)
                ? .reveal : .interlock
        case .build: return .corrode
        case .breakdown: return .suspend
        case .returnSection: return .release
        }
    }

    private static func mutation(for gesture: SynthGesture, tension: Double) -> Double {
        switch gesture {
        case .reveal: return 0.20 + tension * 0.12
        case .interlock: return 0.34 + tension * 0.18
        case .corrode: return 0.66 + tension * 0.28
        case .suspend: return 0.78 + tension * 0.16
        case .release: return 0.28 + tension * 0.12
        }
    }

    private struct MotifPitch {
        let sourceIndex: Int
        let event: EnsembleResolvedEvent
        let frequencyRatio: Double
    }

    /// Resolves every upper note before DSP preparation. The renderer consumes
    /// `upperNotes`; pitch, duration, velocity, gate, and timbre selection have
    /// one canonical Core owner.
    private static func resolvedUpperNotes(
        scene: TechnoScene,
        dna: SceneDNA,
        kind: AutonomousPhraseKind,
        world: SynthWorldDNA,
        resolved: ResolvedPerformanceBar,
        gesture: SynthGesture,
        mutationAmount: Double,
        forceHomeUpperTimbre: Bool,
        relationalSteps: [RelationalArticulation],
        composition: PhraseCompositionBar
    ) -> (notes: [ResolvedUpperNote], tonalEnvelopeExpansionEligible: Bool,
          timingRelation: UpperTimingRelation) {
        let performance = resolved.performance
        func instrument(_ role: SynthRole) -> InstrumentAssignment {
            InstrumentPalette.resolveUpper(
                role: role,
                world: world,
                kind: kind,
                gesture: gesture,
                chapter: resolved.interlockChapter,
                mutationAmount: mutationAmount,
                forceHome: forceHomeUpperTimbre,
                pulseEchoEnabled: resolved.pulseEchoEnabled,
                performanceCharacter: resolved.performanceCharacter
            )
        }
        let motifPitches = resolvedMotifPitches(
            dna: dna,
            performance: performance,
            events: resolved.ensemble.events.filter { $0.voice == .motif }
        )
        let orderedMotif = motifPitches.sorted {
            if $0.event.step != $1.event.step { return $0.event.step < $1.event.step }
            return $0.sourceIndex < $1.sourceIndex
        }
        let variationEnabled = !forceHomeUpperTimbre &&
            kind != .identityReturn && kind != .majorBreak
        let resonantEligible = variationEnabled &&
            resolved.interlockChapter == .motion &&
            (kind == .contrast || kind == .energyRelease) &&
            orderedMotif.count >= 2
        let resonantIntent: UpperTimbreIntent = resonantEligible
            ? .resonantSequence(amount: mutationAmount)
            : .home
        let slideCandidates = resonantEligible
            ? orderedMotif.indices.dropFirst().filter {
                orderedMotif[$0].event.step > orderedMotif[$0 - 1].event.step &&
                abs(orderedMotif[$0].frequencyRatio - orderedMotif[$0 - 1].frequencyRatio) >
                    0.000_000_001
            }
            : []
        let slideIndex: Int?
        if slideCandidates.isEmpty {
            slideIndex = nil
        } else {
            let selection = SceneDNA.derivedSeed(
                scene: performance.eventSeed,
                domain: 0x51DE_6A7E,
                index: performance.bar
            )
            slideIndex = slideCandidates[Int(selection % UInt64(slideCandidates.count))]
        }

        let anchorInstrument = instrument(.anchor)
        let expansionCandidateIndex: Int? = {
            guard kind == .energyRelease,
                  performance.signatureEvent == .displacedKickRecovery,
                  ((performance.bar % 16) + 16) % 16 == 15,
                  resolved.arrangementGesture == .structuralMarker,
                  anchorInstrument.architecture == .tonalMotion else {
                return nil
            }
            // Leave at least one sixteenth of this bar for the longer release
            // to become observable; slide notes retain their legato contract.
            guard let index = orderedMotif.indices.last,
                  index != slideIndex,
                  orderedMotif[index].event.step <= 12 else {
                return nil
            }
            return index
        }()
        let tonalEnvelopeExpansionEligible = expansionCandidateIndex != nil

        let baseMotifDuration = performance.transformations.contains(.extend) ? 2.5 : 1.5
        var notes = orderedMotif.enumerated().map { index, pitch in
            let articulation = relationalSteps[pitch.event.step]
            let isSlide = index == slideIndex
            let leadsIntoSlide = slideIndex.map { index + 1 == $0 } ?? false
            let legatoDuration = leadsIntoSlide
                ? Double(orderedMotif[index + 1].event.step - pitch.event.step)
                : baseMotifDuration
            let startRatio = isSlide
                ? orderedMotif[index - 1].frequencyRatio
                : pitch.frequencyRatio
            return ResolvedUpperNote(
                role: .anchor,
                onsetStep: pitch.event.step,
                durationInSteps: max(baseMotifDuration, legatoDuration),
                startFrequencyRatio: startRatio,
                endFrequencyRatio: pitch.frequencyRatio,
                velocity: min(
                    1,
                    (0.66 + performance.accent(at: pitch.event.step) * 0.24) *
                        articulation.velocityScale
                ),
                gate: isSlide ? .slide : .retrigger,
                timbreIntent: resonantIntent,
                envelopeRelation: index == expansionCandidateIndex &&
                    !forceHomeUpperTimbre ? .sustainedWash : .home,
                spectralReveal: UpperSpectralRevealResolver.articulation(
                    role: .anchor,
                    narrative: resolved.narrative,
                    phraseKind: kind,
                    forceHome: forceHomeUpperTimbre,
                    step: pitch.event.step
                ),
                instrument: anchorInstrument
            )
        }

        if let arpeggiator = composition.arpeggiator {
            notes.removeAll { $0.role == .anchor }
            notes.append(contentsOf: arpeggiator.steps.map { step in
                ResolvedUpperNote(
                    role: .anchor,
                    onsetStep: step.onsetStep,
                    durationInSteps: step.durationInSteps,
                    startFrequencyRatio: step.frequencyRatio,
                    endFrequencyRatio: step.frequencyRatio,
                    velocity: step.velocity,
                    gate: .retrigger,
                    timbreIntent: resonantIntent,
                    spectralReveal: UpperSpectralRevealResolver.articulation(
                        role: .anchor,
                        narrative: resolved.narrative,
                        phraseKind: kind,
                        forceHome: forceHomeUpperTimbre,
                        step: step.onsetStep
                    ),
                    instrument: anchorInstrument
                )
            })
        }

        let detunedEligible = variationEnabled && resolved.interlockChapter == .tone
        let detunedIntent: UpperTimbreIntent = detunedEligible
            ? .detunedMotion(amount: mutationAmount)
            : .home
        let baseFrequencyRatio = motifPitches.first?.frequencyRatio ?? 2
        let shadowGestureLevel: Double = switch gesture {
        case .reveal: 0.34
        case .interlock: 0.46
        case .corrode: 0.58
        case .release: 0.38
        case .suspend: 0
        }
        if gesture != .suspend {
            notes.append(contentsOf: motifPitches.map { pitch in
                let octave = pitch.sourceIndex.isMultiple(of: 3) ? 0.5 : 1.0
                let interval = pow(2, Double(world.shadowInterval) / 12)
                var frequency = world.rootFrequency * baseFrequencyRatio * interval * octave
                while frequency < 92 { frequency *= 2 }
                while frequency > 880 { frequency *= 0.5 }
                let articulation = relationalSteps[pitch.event.step]
                return ResolvedUpperNote(
                    role: .shadow,
                    onsetStep: pitch.event.step,
                    durationInSteps: 0.52 * articulation.decayScale,
                    startFrequencyRatio: frequency / world.rootFrequency,
                    endFrequencyRatio: frequency / world.rootFrequency,
                    velocity: min(
                        1,
                        min(0.72, shadowGestureLevel * max(0.35, pitch.event.intensity)) *
                            articulation.velocityScale
                    ),
                    gate: .retrigger,
                    timbreIntent: detunedIntent,
                    instrument: instrument(.shadow)
                )
            })
        }

        let responseEvents = resolved.ensemble.events.filter { $0.voice == .response }
        if gesture != .suspend, !responseEvents.isEmpty, scene.melodicity > 0.18 {
            let responseInterval = pow(2, Double(world.responseInterval) / 12)
            let frequency = min(
                1_200,
                max(120, world.rootFrequency * baseFrequencyRatio * responseInterval)
            )
            notes.append(contentsOf: responseEvents.map { event in
                let articulation = relationalSteps[event.step]
                return ResolvedUpperNote(
                    role: .response,
                    onsetStep: event.step,
                    durationInSteps: 1.8,
                    startFrequencyRatio: frequency / world.rootFrequency,
                    endFrequencyRatio: frequency / world.rootFrequency,
                    velocity: min(
                        0.76,
                        (event.intensity + scene.melodicity * 0.24) * articulation.velocityScale
                    ),
                    gate: .retrigger,
                    timbreIntent: detunedIntent,
                    instrument: instrument(.response)
                )
            })
        }

        let atmosphereEvents = resolved.ensemble.events.filter { $0.voice == .atmosphere }
        if !atmosphereEvents.isEmpty, scene.atmosphere > 0.08 || scene.drone > 0.01 {
            let startRatio = resolved.performance.section == .breakdown ? 1.5 : 2.0
            let endScale = gesture == .suspend ? 1.018 : 1.003
            notes.append(contentsOf: atmosphereEvents.map { event in
                ResolvedUpperNote(
                    role: .atmosphere,
                    onsetStep: event.step,
                    durationInSteps: max(
                        ResolvedUpperNote.minimumDurationInSteps,
                        16 - Double(event.step)
                    ),
                    startFrequencyRatio: startRatio,
                    endFrequencyRatio: startRatio * endScale,
                    velocity: min(0.72, event.intensity + scene.atmosphere * 0.22),
                    gate: .retrigger,
                    timbreIntent: .home,
                    instrument: instrument(.atmosphere)
                )
            })
        }

        let transitionEvents = resolved.ensemble.events.filter { $0.voice == .transition }
        let renderedTransitionEvents: [EnsembleResolvedEvent]
        if gesture != .suspend {
            renderedTransitionEvents = transitionEvents
        } else {
            let spatial = resolved.spatialContrast
            renderedTransitionEvents = transitionEvents.filter {
                spatial.depthPosition == .distant &&
                    spatial.carrierVoice == .transition &&
                    spatial.carrierStep == $0.step
            }
        }
        if !renderedTransitionEvents.isEmpty {
            let endScale = gesture == .corrode ? 3.8 : 1.5
            notes.append(contentsOf: renderedTransitionEvents.map { event in
                ResolvedUpperNote(
                    role: .transition,
                    onsetStep: event.step,
                    durationInSteps: max(
                        ResolvedUpperNote.minimumDurationInSteps,
                        16 - Double(event.step)
                    ),
                    startFrequencyRatio: 2,
                    endFrequencyRatio: 2 * endScale,
                    velocity: min(0.54, event.intensity + mutationAmount * 0.18),
                    gate: .retrigger,
                    timbreIntent: .home,
                    instrument: instrument(.transition)
                )
            })
        }

        let timingEnabled = upperTimingEligible(
            notes: notes,
            chapter: resolved.interlockChapter,
            variationEnabled: variationEnabled
        )
        let aperture = timingEnabled
            ? upperTimingAperture(absoluteBar: performance.bar) : 0
        let leadPerformanceEnabled = !timingEnabled && variationEnabled &&
            kind == .lock && resolved.interlockChapter == .home &&
            resolved.performanceCharacter == .melodicGlow &&
            notes.filter { $0.role == .anchor && $0.gate == .retrigger }.count >= 2
        let timingRelation: UpperTimingRelation
        if aperture > 0 {
            timingRelation = .harmonicCascade
            notes = notes.map { note in
                note.withTimingOffsetInSteps(upperTimingOffsetInSteps(
                    for: note.role,
                    absoluteBar: performance.bar,
                    enabled: timingEnabled
                ))
            }
        } else if leadPerformanceEnabled {
            timingRelation = .leadPerformance
            let orderedAnchorIndices = notes.indices.filter {
                notes[$0].role == .anchor && notes[$0].gate == .retrigger
            }.sorted { notes[$0].onsetStep < notes[$1].onsetStep }
            for (performanceIndex, noteIndex) in orderedAnchorIndices.enumerated()
                where performanceIndex > 0 {
                notes[noteIndex] = notes[noteIndex].withTimingOffsetInSteps(
                    leadPerformanceOffsetInSteps(
                        performanceIndex: performanceIndex
                    )
                )
            }
        } else {
            timingRelation = .aligned
        }

        return (notes.sorted {
            if $0.onsetStep != $1.onsetStep { return $0.onsetStep < $1.onsetStep }
            let lhsRole = SynthRole.allCases.firstIndex(of: $0.role) ?? 0
            let rhsRole = SynthRole.allCases.firstIndex(of: $1.role) ?? 0
            return lhsRole < rhsRole
        }, tonalEnvelopeExpansionEligible, timingRelation)
    }

    package static let minimumLeadPerformanceOffsetInSteps = 0.018
    package static let maximumLeadPerformanceOffsetInSteps = 0.036

    package static func leadPerformanceOffsetInSteps(
        performanceIndex: Int
    ) -> Double {
        guard performanceIndex > 0 else { return 0 }
        return performanceIndex.isMultiple(of: 2)
            ? maximumLeadPerformanceOffsetInSteps
            : minimumLeadPerformanceOffsetInSteps
    }

    private static func resolvedMotifPitches(
        dna: SceneDNA,
        performance: PerformanceBar,
        events: [EnsembleResolvedEvent]
    ) -> [MotifPitch] {
        let answer = performance.transformations.contains(.answer) ||
            performance.signatureEvent == .alteredMotifAnswer
        let shadow = performance.signatureEvent == .harmonicShadow ? 1 : 0
        return events.enumerated().map { index, event in
            let requestedDegree = dna.motif.degrees[index % dna.motif.degrees.count] +
                (answer ? 7 : 0) + shadow
            let degree = dna.nearestModalDegree(to: requestedDegree)
            return MotifPitch(
                sourceIndex: index,
                event: event,
                frequencyRatio: pow(2, Double(degree) / 12)
            )
        }
    }

}
