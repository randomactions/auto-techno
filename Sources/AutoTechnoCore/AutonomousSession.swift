import Foundation

package enum AutonomousPhraseKind: String, CaseIterable, Codable, Sendable {
    case lock
    case contrast
    case majorBreak
    case energyRelease
    case identityReturn
}

package enum SixteenthPulseClass: String, CaseIterable, Sendable {
    case downbeat
    case leadingWeak
    case upbeat
    case trailingWeak

    package init(step: Int) {
        switch ((step % 4) + 4) % 4 {
        case 0: self = .downbeat
        case 1: self = .leadingWeak
        case 2: self = .upbeat
        default: self = .trailingWeak
        }
    }
}

package enum WeakSixteenthStage: String, CaseIterable, Sendable {
    case skeleton
    case contour
    case syncopatedLean
    case pullback

    package init(absoluteBar: Int) {
        switch (((absoluteBar % 16) + 16) % 16) / 4 {
        case 0: self = .skeleton
        case 1: self = .contour
        case 2: self = .syncopatedLean
        default: self = .pullback
        }
    }
}

/// Score-owned physical contact position for the existing delicate groove
/// pulse. These names describe relative spectral zones, not a sampled or
/// simulated acoustic instrument.
package enum GroovePulseStrikeZone: String, CaseIterable, Sendable {
    case center
    case middle
    case edge
}

package struct GroovePulseArticulation: Equatable, Sendable {
    package let step: Int
    package let pulseClass: SixteenthPulseClass
    package let stage: WeakSixteenthStage
    package let intensity: Double
    package let timingOffsetInSteps: Double
    package let strikeZone: GroovePulseStrikeZone
    package let damping: Double
    package let timbreMicrovariation: Double

    package init(step: Int, pulseClass: SixteenthPulseClass,
                 stage: WeakSixteenthStage, intensity: Double,
                 timingOffsetInSteps: Double,
                 strikeZone: GroovePulseStrikeZone,
                 damping: Double,
                 timbreMicrovariation: Double) {
        self.step = ((step % 16) + 16) % 16
        self.pulseClass = pulseClass
        self.stage = stage
        self.intensity = min(1, max(0, intensity))
        self.timingOffsetInSteps = min(0.12, max(0, timingOffsetInSteps))
        self.strikeZone = strikeZone
        self.damping = min(0.75, max(0.25, damping))
        self.timbreMicrovariation = min(0.04, max(-0.04, timbreMicrovariation))
    }
}

/// Semantic decay relationship for an already-resolved closed-hat score event.
/// The renderer owns the bounded envelope value associated with each role.
package enum ClosedHatDecayRole: String, CaseIterable, Sendable {
    case neutral
    case openHatCompanion
}

package struct ClosedHatDecayArticulation: Equatable, Sendable {
    package let scoreEventIndex: Int
    package let step: Int
    package let role: ClosedHatDecayRole

    package init(scoreEventIndex: Int, step: Int, role: ClosedHatDecayRole) {
        self.scoreEventIndex = max(0, scoreEventIndex)
        self.step = ((step % 16) + 16) % 16
        self.role = role
    }
}

package enum EnsembleVoice: String, CaseIterable, Sendable {
    case kick
    case bass
    case rumble
    case percussion
    case clap
    case openHat
    case tunedTom
    case metallic
    case motif
    case response
    case atmosphere
    case transition
    case groovePulse

    package var role: PerformanceRole {
        switch self {
        case .kick, .bass, .rumble, .tunedTom: .foundation
        case .percussion, .clap, .openHat, .metallic, .groovePulse: .percussion
        case .motif: .motif
        case .response: .response
        case .atmosphere: .atmosphere
        case .transition: .transition
        }
    }
}

/// A relational depth intention for an already-resolved event. Foreground is
/// the neutral, fully dry position; distant events retain their onset and
/// identity while a filtered send places them behind the groove.
package enum SpatialDepthPosition: String, CaseIterable, Sendable {
    case foreground
    case distant
}

/// Immutable spatial values shared by event metadata and detached rendering.
/// The optional carrier identity makes a foreground bar explicit without
/// inventing a placeholder event that could diverge from the ensemble score.
package struct SpatialContrastArticulation: Equatable, Sendable {
    package let depthPosition: SpatialDepthPosition
    package let carrierVoice: EnsembleVoice?
    package let carrierStep: Int?
    package let dryScale: Double
    package let reverbSend: Double
    package let highPassHz: Double
    package let lowPassHz: Double

    package init(depthPosition: SpatialDepthPosition,
                 carrierVoice: EnsembleVoice?, carrierStep: Int?,
                 dryScale: Double, reverbSend: Double,
                 highPassHz: Double, lowPassHz: Double) {
        let normalizedStep = carrierStep.map(Self.step)
        let hasCarrier = carrierVoice != nil && normalizedStep != nil
        self.depthPosition = hasCarrier ? depthPosition : .foreground
        self.carrierVoice = hasCarrier ? carrierVoice : nil
        self.carrierStep = hasCarrier ? normalizedStep : nil
        self.dryScale = hasCarrier ? min(1, max(0, dryScale)) : 1
        self.reverbSend = hasCarrier ? min(1, max(0, reverbSend)) : 0
        self.highPassHz = min(20_000, max(20, highPassHz))
        self.lowPassHz = min(20_000, max(self.highPassHz, lowPassHz))
    }

    package static let foreground = SpatialContrastArticulation(
        depthPosition: .foreground,
        carrierVoice: nil,
        carrierStep: nil,
        dryScale: 1,
        reverbSend: 0,
        highPassHz: 300,
        lowPassHz: 4_200
    )

    package func applies(to event: EnsembleResolvedEvent) -> Bool {
        carrierVoice == event.voice && carrierStep == event.step
    }

    private static func step(_ value: Int) -> Int {
        ((value % 16) + 16) % 16
    }
}

/// Bounded cross-phrase memory for the selective depth gesture. Retaining the
/// last macro prevents adaptive phrase boundaries from selecting two distant
/// carriers inside one global sixteen-bar macro.
package struct SpatialContrastState: Equatable, Sendable {
    package private(set) var previousCarrierVoice: EnsembleVoice?
    package private(set) var lastCarrierMacroIndex: Int?

    package init(previousCarrierVoice: EnsembleVoice? = nil,
                 lastCarrierMacroIndex: Int? = nil) {
        self.previousCarrierVoice = previousCarrierVoice
        self.lastCarrierMacroIndex = lastCarrierMacroIndex.map { max(0, $0) }
    }

    package func resolving(ensemble: EnsembleContext,
                           kind: AutonomousPhraseKind,
                           gesture: ArrangementGesture,
                           absoluteBar: Int,
                           relationship: LongHorizonEnergyRelationship = .hold)
        -> (SpatialContrastArticulation, SpatialContrastState) {
        if relationship == .lower || relationship == .home {
            return (.foreground, self)
        }
        let eligibleVoices: [EnsembleVoice]
        let send: Double
        if relationship == .hold {
            switch (kind, gesture) {
            case (.contrast, .turnaround):
                eligibleVoices = [.response, .transition]
                send = 0.22
            case (.majorBreak, .structuralMarker):
                eligibleVoices = [.transition, .atmosphere]
                send = 0.30
            default:
                // Releases and identity returns are therefore explicitly dry,
                // as are bars without an authored spatial contrast.
                return (.foreground, self)
            }
        } else {
            guard gesture == .gearShift || gesture == .turnaround ||
                    gesture == .structuralMarker else {
                return (.foreground, self)
            }
            eligibleVoices = relationship == .raise
                ? [.atmosphere, .transition, .response]
                : [.response, .atmosphere, .transition]
            send = relationship == .raise ? 0.30 : 0.24
        }

        let macroIndex = max(0, absoluteBar) / 16
        guard lastCarrierMacroIndex != macroIndex else {
            return (.foreground, self)
        }

        let candidates = eligibleVoices.flatMap { voice in
            ensemble.events.filter { $0.voice == voice }
        }
        guard !candidates.isEmpty else { return (.foreground, self) }
        let selected = candidates.first { candidate in
            candidates.count == 1 || candidate.voice != previousCarrierVoice
        } ?? candidates[0]
        let articulation = SpatialContrastArticulation(
            depthPosition: .distant,
            carrierVoice: selected.voice,
            carrierStep: selected.step,
            dryScale: 0.72,
            reverbSend: send,
            highPassHz: 300,
            lowPassHz: 4_200
        )
        return (
            articulation,
            SpatialContrastState(
                previousCarrierVoice: selected.voice,
                lastCarrierMacroIndex: macroIndex
            )
        )
    }
}

/// Phrase-scale movement of the dominant motif. The direction is derived from
/// the resolved presence endpoints and coordinates additive support without
/// changing the motif's pitch, rhythm, or timbral identity.
package enum NarrativeDirection: String, CaseIterable, Sendable {
    case emerging
    case holding
    case receding
}

/// Fully resolved protagonist contour and supporting-role state for one bar.
/// Renderers consume the same interpolation that metadata reports.
package struct NarrativeArticulation: Equatable, Sendable {
    package let direction: NarrativeDirection
    package let presenceStart: Double
    package let presenceEnd: Double
    package let activeSupportingRoles: [PerformanceRole]

    package init(presenceStart: Double, presenceEnd: Double,
                 activeSupportingRoles: [PerformanceRole]) {
        self.presenceStart = Self.clamp(presenceStart)
        self.presenceEnd = Self.clamp(presenceEnd)
        if self.presenceEnd > self.presenceStart + 0.000_001 {
            direction = .emerging
        } else if self.presenceEnd < self.presenceStart - 0.000_001 {
            direction = .receding
        } else {
            direction = .holding
        }
        self.activeSupportingRoles = Self.supportingRoles(activeSupportingRoles)
    }

    package static let initial = NarrativeArticulation(
        presenceStart: 0.50,
        presenceEnd: 0.50,
        activeSupportingRoles: [.percussion]
    )

    package func presence(atStep step: Int) -> Double {
        let boundedStep = min(15, max(0, step))
        let progress = Double(boundedStep) / 15
        return presenceStart + (presenceEnd - presenceStart) * progress
    }

    package func motifGainScale(atStep step: Int) -> Double {
        0.82 + 0.28 * presence(atStep: step)
    }

    package func motifSpectralScale(atStep step: Int) -> Double {
        0.94 + 0.12 * presence(atStep: step)
    }

    fileprivate static func supportingRoles(_ roles: [PerformanceRole]) -> [PerformanceRole] {
        let allowed: [PerformanceRole] = [.percussion, .response, .atmosphere]
        let requested = Set(roles)
        return allowed.filter(requested.contains)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// Bounded cross-phrase state for the narrative protagonist and its three
/// possible supporting roles. A pending release settlement preserves the
/// exact 0.90 macro peak when that peak lands on a phrase's final boundary.
package struct NarrativeEvolutionState: Equatable, Sendable {
    package private(set) var protagonistPresence: Double
    package private(set) var activeSupportingRoles: [PerformanceRole]
    package private(set) var releaseSettlementPending: Bool

    package init(protagonistPresence: Double = 0.50,
                 activeSupportingRoles: [PerformanceRole] = [.percussion],
                 releaseSettlementPending: Bool = false) {
        self.protagonistPresence = min(1, max(0, protagonistPresence))
        self.activeSupportingRoles = NarrativeArticulation.supportingRoles(activeSupportingRoles)
        self.releaseSettlementPending = releaseSettlementPending
    }
}

package struct EnsembleEventProposal: Equatable, Sendable {
    package let voice: EnsembleVoice
    package let requestedStep: Int
    package let alternateSteps: [Int]
    package let priority: Int
    package let intensity: Double
    package let essential: Bool

    package init(voice: EnsembleVoice, requestedStep: Int, alternateSteps: [Int] = [],
                priority: Int, intensity: Double, essential: Bool = false) {
        self.voice = voice
        self.requestedStep = Self.step(requestedStep)
        self.alternateSteps = alternateSteps.map(Self.step)
        self.priority = priority
        self.intensity = min(1, max(0, intensity))
        self.essential = essential
    }

    private static func step(_ value: Int) -> Int {
        ((value % 16) + 16) % 16
    }
}

package struct EnsembleResolvedEvent: Equatable, Sendable {
    package let voice: EnsembleVoice
    package let step: Int
    package let intensity: Double
    package let relocated: Bool

    package init(voice: EnsembleVoice, step: Int, intensity: Double, relocated: Bool) {
        self.voice = voice
        self.step = ((step % 16) + 16) % 16
        self.intensity = min(1, max(0, intensity))
        self.relocated = relocated
    }
}

package struct EnsembleContext: Equatable, Sendable {
    package let focusRole: PerformanceRole
    package let events: [EnsembleResolvedEvent]
    package let kickAnchors: [Int]
    package let intentionalPileup: Bool

    package init(focusRole: PerformanceRole, events: [EnsembleResolvedEvent],
                kickAnchors: [Int], intentionalPileup: Bool) {
        self.focusRole = focusRole
        self.events = events
        self.kickAnchors = kickAnchors.sorted()
        self.intentionalPileup = intentionalPileup
    }
}

/// Score-owned relationship between the existing kick grid and a bounded
/// phrase-level ambiguity arc. Withholding removes only already-resolved kick
/// events; it never shifts the transport, bar line, or surrounding score.
package enum KickSyntaxRole: String, CaseIterable, Sendable {
    case grounded
    case withheld
    case recovery
}

/// One bounded input-window -> delay -> output-window relationship on the
/// existing percussion role. The score chooses only geometry; renderer-owned
/// filter, feedback, gain, and boundary fades remain one canonical contract.
package enum PercussionEchoTextureRelation: String, CaseIterable, Sendable {
    case gatedEcho
    case anticipationSwell
}

package struct PercussionEchoTextureArticulation: Equatable, Sendable {
    package let relation: PercussionEchoTextureRelation
    package let inputStep: Int
    package let outputStartStep: Int
    package let outputEndStep: Int

    package init(
        relation: PercussionEchoTextureRelation = .gatedEcho,
        inputStep: Int,
        outputStartStep: Int,
        outputEndStep: Int
    ) {
        self.relation = relation
        self.inputStep = inputStep
        self.outputStartStep = outputStartStep
        self.outputEndStep = outputEndStep
    }
}

/// Resolves the percussion return after ensemble arbitration so every active
/// relation owns an audible, already-resolved percussion event. The established
/// contrast relation remains a later gated echo; the final withheld release bar
/// may reinterpret the same wet tail as a bounded anticipation swell.
package enum PercussionEchoTextureResolver {
    package static let inputWindowLengthInSteps = 1
    package static let outputDelayInSteps = 4
    package static let outputWindowLengthInSteps = 4
    package static let latestInputStep = 7
    package static let anticipationSwellMacroPosition = 14
    package static let anticipationSwellOutputEndStep =
        ClimaxHangContract.startStep
    package static let minimumAnticipationRiseDB = 3.0

    package static func articulation(
        ensemble: EnsembleContext,
        kind: AutonomousPhraseKind,
        character: PerformanceCharacter,
        gesture: ArrangementGesture,
        kickSyntaxRole: KickSyntaxRole = .grounded,
        absoluteBar: Int? = nil
    ) -> PercussionEchoTextureArticulation? {
        guard let source = eligibleSourceEvents(in: ensemble).first else {
            return nil
        }
        if kind == .contrast,
           character == .brokenSuspension,
           gesture == .gearShift,
           kickSyntaxRole == .grounded {
            return PercussionEchoTextureArticulation(
                relation: .gatedEcho,
                inputStep: source.step,
                outputStartStep: source.step + outputDelayInSteps,
                outputEndStep: source.step + outputDelayInSteps +
                    outputWindowLengthInSteps
            )
        }
        if kind == .energyRelease,
           (character == .peakDrive || character == .acidPressure),
           gesture == .steady,
           kickSyntaxRole == .withheld,
           let absoluteBar,
           positiveModulo(absoluteBar, 16) == anticipationSwellMacroPosition {
            return PercussionEchoTextureArticulation(
                relation: .anticipationSwell,
                inputStep: source.step,
                outputStartStep: source.step + inputWindowLengthInSteps,
                outputEndStep: anticipationSwellOutputEndStep
            )
        }
        return nil
    }

    package static func eligibleSourceEvents(
        in ensemble: EnsembleContext
    ) -> [EnsembleResolvedEvent] {
        ensemble.events.filter { event in
            event.step <= latestInputStep && isPercussionTextureVoice(event.voice)
        }.sorted { lhs, rhs in
            if lhs.step != rhs.step { return lhs.step < rhs.step }
            return voiceOrder(lhs.voice) < voiceOrder(rhs.voice)
        }
    }

    private static func isPercussionTextureVoice(_ voice: EnsembleVoice) -> Bool {
        switch voice {
        case .percussion, .clap, .openHat, .metallic, .groovePulse:
            true
        case .kick, .bass, .rumble, .tunedTom, .motif, .response,
                .atmosphere, .transition:
            false
        }
    }

    private static func voiceOrder(_ voice: EnsembleVoice) -> Int {
        EnsembleVoice.allCases.firstIndex(of: voice) ?? Int.max
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

/// The single immutable score consumed by rendering for one bar. Keeping the
/// musical bar and its arbitrated events together prevents telemetry and PCM
/// from describing different performances.
package struct ResolvedPerformanceBar: Equatable, Sendable {
    package let performance: PerformanceBar
    package let ensemble: EnsembleContext
    package let arrangementGesture: ArrangementGesture
    package let percussionGear: PercussionGear
    package let performanceCharacter: PerformanceCharacter
    package let foundationBehavior: FoundationBehavior
    package let foundationRhythmicRelation: FoundationRhythmicRelation
    package let foundationCompanion: FoundationCompanion
    package let pulseEchoEnabled: Bool
    package let interlockChapter: InterlockChapter
    package let groovePulses: [GroovePulseArticulation]
    package let closedHatDecayArticulations: [ClosedHatDecayArticulation]
    package let upperPercussionTailArticulations:
        [UpperPercussionTailArticulation]
    package let modalPercussionArticulations: [ModalPercussionArticulation]
    package let spatialContrast: SpatialContrastArticulation
    package let narrative: NarrativeArticulation
    package let kickSyntaxRole: KickSyntaxRole
    package let climaxHang: ClimaxHangArticulation?
    package let percussionEchoTexture: PercussionEchoTextureArticulation?
    package let harmonicDisclosureRelationship: LongHorizonEnergyRelationship
    package let kickMorphology: KickMorphologyArticulation

    package init(performance: PerformanceBar, ensemble: EnsembleContext,
                 arrangementGesture: ArrangementGesture, percussionGear: PercussionGear,
                 performanceCharacter: PerformanceCharacter? = nil,
                 foundationBehavior: FoundationBehavior? = nil,
                 foundationRhythmicRelation: FoundationRhythmicRelation = .established,
                 foundationCompanion: FoundationCompanion, pulseEchoEnabled: Bool,
                 interlockChapter: InterlockChapter,
                 groovePulses: [GroovePulseArticulation] = [],
                 closedHatDecayArticulations: [ClosedHatDecayArticulation]? = nil,
                 upperPercussionTailArticulations:
                    [UpperPercussionTailArticulation]? = nil,
                 modalPercussionArticulations: [ModalPercussionArticulation] = [],
                 spatialContrast: SpatialContrastArticulation = .foreground,
                 narrative: NarrativeArticulation = .initial,
                 kickSyntaxRole: KickSyntaxRole = .grounded,
                 climaxHang: ClimaxHangArticulation? = nil,
                 percussionEchoTexture: PercussionEchoTextureArticulation? = nil,
                 harmonicDisclosureRelationship:
                    LongHorizonEnergyRelationship = .hold,
                 kickMorphology: KickMorphologyArticulation? = nil) {
        self.performance = performance
        self.ensemble = ensemble
        self.arrangementGesture = arrangementGesture
        self.percussionGear = percussionGear
        let resolvedFoundationBehavior = foundationBehavior ?? FoundationBehavior(
            companion: foundationCompanion
        )
        let derivedPerformanceCharacter: PerformanceCharacter = switch resolvedFoundationBehavior {
        case .subPulse, .monotone: .hypnoticLock
        case .point, .pump: .peakDrive
        case .kickTail, .tunedPercussive: .brokenSuspension
        case .absent: .ambientDrift
        }
        self.performanceCharacter = performanceCharacter ?? derivedPerformanceCharacter
        self.foundationBehavior = resolvedFoundationBehavior
        self.foundationRhythmicRelation = foundationRhythmicRelation
        self.foundationCompanion = foundationCompanion
        self.pulseEchoEnabled = pulseEchoEnabled && foundationCompanion != .monoRumble
        self.interlockChapter = interlockChapter
        self.groovePulses = groovePulses.sorted { $0.step < $1.step }
        self.closedHatDecayArticulations = closedHatDecayArticulations ??
            ClosedHatDecayResolver.articulations(from: ensemble)
        self.upperPercussionTailArticulations =
            upperPercussionTailArticulations ??
            UpperPercussionTailResolver.articulations(
                from: ensemble,
                phraseKind: .identityReturn,
                performanceCharacter: self.performanceCharacter
            )
        self.modalPercussionArticulations = modalPercussionArticulations.sorted {
            $0.scoreEventIndex < $1.scoreEventIndex
        }
        self.spatialContrast = spatialContrast
        self.narrative = narrative
        self.kickSyntaxRole = kickSyntaxRole
        self.climaxHang = climaxHang
        self.percussionEchoTexture = percussionEchoTexture
        self.harmonicDisclosureRelationship = harmonicDisclosureRelationship
        self.kickMorphology = kickMorphology ??
            KickMorphologyResolver.legacyAnchor(
                sessionSeed: performance.eventSeed,
                absoluteBar: performance.bar
            )
    }

    package func groovePulse(at step: Int) -> GroovePulseArticulation? {
        groovePulses.first { $0.step == ((step % 16) + 16) % 16 }
    }

    package func closedHatDecay(atEventIndex index: Int) -> ClosedHatDecayArticulation? {
        closedHatDecayArticulations.first { $0.scoreEventIndex == index }
    }

    package func modalPercussion(
        atEventIndex index: Int
    ) -> ModalPercussionArticulation? {
        modalPercussionArticulations.first { $0.scoreEventIndex == index }
    }

    package func upperPercussionTail(
        atEventIndex index: Int
    ) -> UpperPercussionTailArticulation? {
        upperPercussionTailArticulations.first {
            $0.scoreEventIndex == index
        }
    }
}

/// Resolves at most one semantic envelope relation for each of the bounded four
/// closed-hat score events. Matching happens after arbitration, so relocation
/// can create or remove a companion without leaving stale proposal metadata.
package enum ClosedHatDecayResolver {
    package static func articulations(
        from ensemble: EnsembleContext
    ) -> [ClosedHatDecayArticulation] {
        var result: [ClosedHatDecayArticulation] = []
        result.reserveCapacity(4)
        for (scoreEventIndex, event) in ensemble.events.enumerated() {
            guard event.voice == .percussion else { continue }
            guard result.count < 4 else { break }
            let sharesStepWithOpenHat = ensemble.events.contains {
                $0.voice == .openHat && $0.step == event.step
            }
            result.append(ClosedHatDecayArticulation(
                scoreEventIndex: scoreEventIndex,
                step: event.step,
                role: sharesStepWithOpenHat ? .openHatCompanion : .neutral
            ))
        }
        return result
    }
}

/// Applies one deterministic metric-syntax arc after the complete baseline
/// phrase has been resolved. The setup and misleading weak-pulse material stay
/// on the original grid; only the two existing kick subsets immediately before
/// the unchanged recovery marker are withheld.
package enum KickSyntaxResolver {
    package static let canonicalWeakPulseSteps = [3, 7, 11, 15]

    package static func resolve(
        resolvedBars: [ResolvedPerformanceBar],
        kind: AutonomousPhraseKind,
        paidDebtIDs: [Int]
    ) -> [ResolvedPerformanceBar] {
        guard resolvedBars.count <= 16,
              kind == .energyRelease,
              !paidDebtIDs.isEmpty,
              resolvedBars.allSatisfy({ $0.kickSyntaxRole == .grounded }),
              let recoveryIndex = resolvedBars.firstIndex(where: {
                  $0.arrangementGesture == .structuralMarker
              }),
              recoveryIndex >= 3 else {
            return resolvedBars
        }

        let setupIndex = recoveryIndex - 3
        let firstWithheldIndex = recoveryIndex - 2
        let secondWithheldIndex = recoveryIndex - 1
        let setup = resolvedBars[setupIndex]
        let firstWithheld = resolvedBars[firstWithheldIndex]
        let secondWithheld = resolvedBars[secondWithheldIndex]
        let recovery = resolvedBars[recoveryIndex]
        let span = [setup, firstWithheld, secondWithheld, recovery]
        let spanIndices = [
            setupIndex, firstWithheldIndex, secondWithheldIndex, recoveryIndex,
        ]
        let character = setup.performanceCharacter

        guard character == .peakDrive || character == .acidPressure,
              zip(spanIndices, span).allSatisfy({ index, resolved in
                  resolved.performance.bar >= 0 &&
                      resolved.performance.localBar == index &&
                      resolved.performance.phrase == recovery.performance.phrase &&
                      resolved.performance.phraseLength == resolvedBars.count &&
                      resolved.performanceCharacter == character &&
                      resolved.foundationBehavior ==
                        PerformanceCharacterContract.foundationBehavior(
                            for: character,
                            gesture: resolved.arrangementGesture,
                            localBar: resolved.performance.localBar,
                            phraseLength: resolved.performance.phraseLength
                        ) &&
                      resolved.foundationBehavior.companion == .bass &&
                      resolved.foundationCompanion == .bass
              }),
              zip(span, span.dropFirst()).allSatisfy({ previous, next in
                  previous.performance.bar < Int.max &&
                      next.performance.bar == previous.performance.bar + 1
              }),
              span.allSatisfy({
                  $0.ensemble.focusRole == .foundation &&
                      $0.percussionGear == .turnaround
              }),
              setup.arrangementGesture == .steady,
              firstWithheld.arrangementGesture == .steady,
              secondWithheld.arrangementGesture == .steady,
              recovery.arrangementGesture == .structuralMarker,
              macroPosition(recovery.performance.bar) == 15,
              [setup, firstWithheld, secondWithheld].allSatisfy({
                  WeakSixteenthStage(absoluteBar: $0.performance.bar) == .pullback &&
                      hasCanonicalKickScore($0.ensemble)
              }),
              setup.ensemble.events.contains(where: {
                  $0.voice == .kick && $0.step == 0
              }),
              [firstWithheld, secondWithheld].allSatisfy(isEligibleWithheldBaseline),
              recovery.performance.signatureEvent == .displacedKickRecovery,
              hasCanonicalKickScore(recovery.ensemble),
              recovery.ensemble.events.contains(where: {
                  $0.voice == .kick && $0.step == 0
              }) else {
            return resolvedBars
        }

        var result = resolvedBars
        result[firstWithheldIndex] = replacingKickScore(
            in: firstWithheld,
            role: .withheld,
            phraseKind: kind
        )
        result[secondWithheldIndex] = replacingKickScore(
            in: secondWithheld,
            role: .withheld,
            phraseKind: kind
        )
        result[recoveryIndex] = replacingKickScore(
            in: recovery,
            role: .recovery,
            phraseKind: kind
        )
        return result
    }

    private static func isEligibleWithheldBaseline(
        _ resolved: ResolvedPerformanceBar
    ) -> Bool {
        let grooveEventSteps = resolved.ensemble.events
            .filter { $0.voice == .groovePulse }
            .map(\.step)
            .sorted()
        return grooveEventSteps == canonicalWeakPulseSteps &&
            resolved.groovePulses.map(\.step) == canonicalWeakPulseSteps &&
            resolved.ensemble.events.contains { $0.voice == .motif } &&
            !resolved.ensemble.events.contains {
                $0.voice != .kick && $0.step == 0
            }
    }

    private static func hasCanonicalKickScore(_ ensemble: EnsembleContext) -> Bool {
        let eventSteps = ensemble.events
            .filter { $0.voice == .kick }
            .map(\.step)
            .sorted()
        return !eventSteps.isEmpty && eventSteps == ensemble.kickAnchors
    }

    private static func macroPosition(_ absoluteBar: Int) -> Int {
        let remainder = absoluteBar % 16
        return remainder >= 0 ? remainder : remainder + 16
    }

    private static func replacingKickScore(
        in resolved: ResolvedPerformanceBar,
        role: KickSyntaxRole,
        phraseKind: AutonomousPhraseKind
    ) -> ResolvedPerformanceBar {
        let hang = ClimaxHangResolver.articulation(
            kind: phraseKind,
            character: resolved.performanceCharacter,
            gesture: resolved.arrangementGesture,
            kickSyntaxRole: role,
            absoluteBar: resolved.performance.bar
        )
        let ensemble: EnsembleContext
        if role == .withheld {
            let events = resolved.ensemble.events.filter { event in
                event.voice != .kick &&
                    (hang.map { event.step < $0.startStep } ?? true)
            }
            ensemble = EnsembleContext(
                focusRole: resolved.ensemble.focusRole,
                events: events,
                kickAnchors: [],
                intentionalPileup: resolved.ensemble.intentionalPileup
            )
        } else {
            ensemble = resolved.ensemble
        }
        let groovePulses = resolved.groovePulses.filter { pulse in
            hang.map { pulse.step < $0.startStep } ?? true
        }
        return ResolvedPerformanceBar(
            performance: resolved.performance,
            ensemble: ensemble,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            performanceCharacter: resolved.performanceCharacter,
            foundationBehavior: resolved.foundationBehavior,
            foundationRhythmicRelation: resolved.foundationRhythmicRelation,
            foundationCompanion: resolved.foundationCompanion,
            pulseEchoEnabled: resolved.pulseEchoEnabled,
            interlockChapter: resolved.interlockChapter,
            groovePulses: groovePulses,
            closedHatDecayArticulations: ClosedHatDecayResolver.articulations(from: ensemble),
            upperPercussionTailArticulations:
                UpperPercussionTailResolver.articulations(
                    from: ensemble,
                    phraseKind: phraseKind,
                    performanceCharacter: resolved.performanceCharacter
                ),
            modalPercussionArticulations: resolved.modalPercussionArticulations,
            spatialContrast: resolved.spatialContrast,
            narrative: resolved.narrative,
            kickSyntaxRole: role,
            climaxHang: hang,
            percussionEchoTexture: PercussionEchoTextureResolver.articulation(
                ensemble: ensemble,
                kind: phraseKind,
                character: resolved.performanceCharacter,
                gesture: resolved.arrangementGesture,
                kickSyntaxRole: role,
                absoluteBar: resolved.performance.bar
            ),
            harmonicDisclosureRelationship:
                resolved.harmonicDisclosureRelationship,
            kickMorphology: resolved.kickMorphology
        )
    }
}

package enum GroovePulseResolver {
    package static let eventWeight = 0.20

    package static func proposals(absoluteBar: Int, percussionActive: Bool,
                                  majorBreak: Bool,
                                  gesture: ArrangementGesture) -> [EnsembleEventProposal] {
        guard percussionActive, !majorBreak else { return [] }
        let stage = WeakSixteenthStage(absoluteBar: absoluteBar)
        return pattern(stage: stage, gesture: gesture,
                       macroEnding: (absoluteBar + 1).isMultiple(of: 16),
                       majorBreak: majorBreak).map { step, intensity in
            EnsembleEventProposal(
                voice: .groovePulse,
                requestedStep: step,
                priority: 40,
                intensity: intensity
            )
        }
    }

    package static func articulations(from ensemble: EnsembleContext,
                                      absoluteBar: Int,
                                      swingPercent: Double,
                                      percussionGear: PercussionGear,
                                      eventSeed: UInt64) -> [GroovePulseArticulation] {
        let stage = WeakSixteenthStage(absoluteBar: absoluteBar)
        let shuffle = min(0.12, max(0, (swingPercent - 0.5) * 2.0))
        return ensemble.events.compactMap { event in
            guard event.voice == .groovePulse else { return nil }
            let physical = physicalArticulation(
                gear: percussionGear,
                eventSeed: eventSeed,
                step: event.step
            )
            return GroovePulseArticulation(
                step: event.step,
                pulseClass: SixteenthPulseClass(step: event.step),
                stage: stage,
                intensity: event.intensity,
                timingOffsetInSteps: event.step.isMultiple(of: 2) ? 0 : shuffle,
                strikeZone: physical.zone,
                damping: physical.damping,
                timbreMicrovariation: physical.microvariation
            )
        }
    }

    /// Accent grouping is a property of the complete resolved cell, not of
    /// proposals that may later be removed by ensemble arbitration. A partial
    /// cell preserves its already-resolved intensities without reflowing steps.
    package static func resolvingAccentGrouping(
        in ensemble: EnsembleContext,
        absoluteBar: Int,
        gesture: ArrangementGesture,
        majorBreak: Bool
    ) -> EnsembleContext {
        guard !majorBreak,
              WeakSixteenthStage(absoluteBar: absoluteBar) == .syncopatedLean,
              gesture != .minimalize else {
            return ensemble
        }
        let grouped = pattern(
            stage: .syncopatedLean,
            gesture: gesture,
            macroEnding: absoluteBar % 16 == 15
        )
        let grooveEvents = ensemble.events.filter { $0.voice == .groovePulse }
            .sorted { $0.step < $1.step }
        let completeCell = grooveEvents.count == grouped.count &&
            zip(grooveEvents, grouped).allSatisfy { $0.step == $1.0 }
        guard completeCell else { return ensemble }
        let selected = Dictionary(uniqueKeysWithValues: grouped)
        let events = ensemble.events.map { event in
            guard event.voice == .groovePulse,
                  let intensity = selected[event.step] else {
                return event
            }
            return EnsembleResolvedEvent(
                voice: event.voice,
                step: event.step,
                intensity: intensity,
                relocated: event.relocated
            )
        }
        return EnsembleContext(
            focusRole: ensemble.focusRole,
            events: events,
            kickAnchors: ensemble.kickAnchors,
            intentionalPileup: ensemble.intentionalPileup
        )
    }

    private static func physicalArticulation(
        gear: PercussionGear,
        eventSeed: UInt64,
        step: Int
    ) -> (zone: GroovePulseStrikeZone, damping: Double, microvariation: Double) {
        let zone: GroovePulseStrikeZone
        let damping: Double
        switch gear {
        case .anchor:
            zone = .middle
            damping = 0.5
        case .lift:
            zone = .middle
            damping = 0.4
        case .contrast:
            zone = .edge
            damping = 0.25
        case .turnaround:
            zone = .center
            damping = 0.75
        }
        let variationIndex = Int(SceneDNA.derivedSeed(
            scene: eventSeed,
            domain: 0x4752_4F4F_5641_5259,
            index: step
        ) % 5)
        let variation = [-0.04, -0.02, 0.0, 0.02, 0.04][variationIndex]
        return (zone, damping, variation)
    }

    package static func pattern(stage: WeakSixteenthStage,
                                gesture: ArrangementGesture,
                                macroEnding: Bool,
                                majorBreak: Bool = false) -> [(Int, Double)] {
        guard !majorBreak else { return [] }
        switch stage {
        case .skeleton:
            return []
        case .contour:
            return [1, 3, 5, 7, 9, 11, 13, 15].map { step in
                (step, SixteenthPulseClass(step: step) == .leadingWeak ? 0.38 : 0.52)
            }
        case .syncopatedLean where gesture == .minimalize:
            return [(7, 0.42), (15, 0.42)]
        case .syncopatedLean:
            let steps = [1, 3, 5, 7, 9, 11, 13, 15]
            let intensities = [0.30, 0.72, 0.30, 0.30, 0.72, 0.30, 0.30, 0.72]
            return zip(steps, intensities).map { step, intensity in
                (step, intensity)
            }
        case .pullback:
            return [3, 7, 11, 15].map { step in
                (step, macroEnding && step == 15 ? 0.72 : 0.50)
            }
        }
    }
}

package enum EnsembleArbiter {
    /// Resolves the baseline score before rendering. Kick anchors are immutable
    /// during arbitration, while other events may move to declared nearby steps
    /// to preserve gaps. The phrase-level syntax resolver may subsequently
    /// withhold an exact kick subset without moving this grid.
    package static func resolve(proposals: [EnsembleEventProposal], focusRole: PerformanceRole,
                               intentionalPileup: Bool) -> EnsembleContext {
        let ordered = proposals.enumerated().sorted { lhs, rhs in
            if lhs.element.essential != rhs.element.essential {
                return lhs.element.essential && !rhs.element.essential
            }
            if lhs.element.priority != rhs.element.priority {
                return lhs.element.priority > rhs.element.priority
            }
            return lhs.offset < rhs.offset
        }
        let kickAnchors = proposals.filter { $0.voice == .kick }.map(\.requestedStep).sorted()
        let maximumAtOneStep = intentionalPileup ? 6 : 3
        var occupancy = Array(repeating: 0, count: 16)
        var accepted: [EnsembleResolvedEvent] = []

        for entry in ordered {
            let proposal = entry.element
            let candidates = [proposal.requestedStep] + proposal.alternateSteps
            let selected = candidates.first { candidate in
                if occupancy[candidate] >= maximumAtOneStep { return false }
                if proposal.voice == .bass && kickAnchors.contains(candidate) { return false }
                return true
            }
            guard let step = selected ?? (proposal.essential ? proposal.requestedStep : nil) else { continue }
            occupancy[step] += 1
            accepted.append(EnsembleResolvedEvent(
                voice: proposal.voice,
                step: step,
                intensity: proposal.intensity,
                relocated: step != proposal.requestedStep
            ))
        }

        return EnsembleContext(
            focusRole: focusRole,
            events: accepted.sorted {
                if $0.step != $1.step { return $0.step < $1.step }
                return $0.voice.rawValue < $1.voice.rawValue
            },
            kickAnchors: kickAnchors,
            intentionalPileup: intentionalPileup
        )
    }
}

package struct MusicalMemoryBar: Equatable, Sendable {
    package let absoluteBar: Int
    package let phraseIndex: Int
    package let section: SectionKind
    package let tension: Double
    package let roles: [PerformanceRole]
    package let transformations: [MusicalTransformation]
    package let eventSignature: UInt64
    package let activity: Double
    package let repetition: Double
    package let density: Double

    package var roleOccupancy: [PerformanceRole] { roles }

    package init(absoluteBar: Int, phraseIndex: Int, section: SectionKind,
                tension: Double, roles: [PerformanceRole],
                transformations: [MusicalTransformation], eventSignature: UInt64,
                activity: Double, repetition: Double, density: Double) {
        self.absoluteBar = absoluteBar
        self.phraseIndex = phraseIndex
        self.section = section
        self.tension = min(1, max(0, tension))
        self.roles = roles
        self.transformations = transformations
        self.eventSignature = eventSignature
        self.activity = min(1, max(0, activity))
        self.repetition = min(1, max(0, repetition))
        self.density = min(1, max(0, density))
    }
}

package struct SessionDramaticDebt: Equatable, Sendable {
    package let id: Int
    package let openedAtBar: Int
    package let dueByBar: Int
    package let source: AutonomousPhraseKind

    package init(id: Int, openedAtBar: Int, dueByBar: Int, source: AutonomousPhraseKind) {
        self.id = id
        self.openedAtBar = openedAtBar
        self.dueByBar = dueByBar
        self.source = source
    }
}

/// Bounded history at four musical timescales. The phrase and dramatic-arc
/// windows follow actual structural boundaries instead of a fixed grid.
package struct TemporalMusicalMemory: Equatable, Sendable {
    package private(set) var recentBars: [MusicalMemoryBar]
    package private(set) var currentPhrase: [MusicalMemoryBar]
    package private(set) var previousPhrase: [MusicalMemoryBar]
    package private(set) var dramaticArc: [MusicalMemoryBar]
    package private(set) var sessionBars: [MusicalMemoryBar]
    package private(set) var totalBars: Int
    package private(set) var lastContrastBar: Int?
    package private(set) var lastBreakBar: Int?
    package private(set) var lastReleaseBar: Int?
    package private(set) var lastIdentityReturnBar: Int?
    package private(set) var topologyRevision: Int
    package private(set) var openDebts: [SessionDramaticDebt]
    package private(set) var interlockEvolution: InterlockEvolutionState
    package private(set) var spatialContrast: SpatialContrastState
    package private(set) var narrativeEvolution: NarrativeEvolutionState
    package private(set) var recentPerformanceCharacters: [PerformanceCharacter]
    package private(set) var harmonicContinuation: HarmonicContinuationState
    package private(set) var longHorizon: LongHorizonContinuationState

    package init(recentBars: [MusicalMemoryBar] = [], currentPhrase: [MusicalMemoryBar] = [],
                previousPhrase: [MusicalMemoryBar] = [], dramaticArc: [MusicalMemoryBar] = [],
                sessionBars: [MusicalMemoryBar] = [], totalBars: Int = 0,
                lastContrastBar: Int? = nil, lastBreakBar: Int? = nil,
                lastReleaseBar: Int? = nil, lastIdentityReturnBar: Int? = nil,
                topologyRevision: Int = 0, openDebts: [SessionDramaticDebt] = [],
                interlockEvolution: InterlockEvolutionState = InterlockEvolutionState(),
                spatialContrast: SpatialContrastState = SpatialContrastState(),
                narrativeEvolution: NarrativeEvolutionState = NarrativeEvolutionState(),
                recentPerformanceCharacters: [PerformanceCharacter] = [],
                harmonicContinuation: HarmonicContinuationState = HarmonicContinuationState(),
                longHorizon: LongHorizonContinuationState? = nil) {
        self.recentBars = Array(recentBars.suffix(4))
        self.currentPhrase = Array(currentPhrase.suffix(16))
        self.previousPhrase = Array(previousPhrase.suffix(16))
        self.dramaticArc = Array(dramaticArc.suffix(128))
        self.sessionBars = Array(sessionBars.suffix(256))
        self.totalBars = max(0, totalBars)
        self.lastContrastBar = lastContrastBar
        self.lastBreakBar = lastBreakBar
        self.lastReleaseBar = lastReleaseBar
        self.lastIdentityReturnBar = lastIdentityReturnBar
        self.topologyRevision = max(0, topologyRevision)
        self.openDebts = openDebts
        self.interlockEvolution = interlockEvolution
        self.spatialContrast = spatialContrast
        self.narrativeEvolution = narrativeEvolution
        self.recentPerformanceCharacters = Array(recentPerformanceCharacters.suffix(2))
        self.harmonicContinuation = harmonicContinuation
        self.longHorizon = longHorizon ?? .unbound(
            startingPhraseIndex: (currentPhrase.last?.phraseIndex).map {
                $0 == Int.max ? Int.max : $0 + 1
            } ?? 0,
            startingBar: totalBars
        )
    }

    package var barsSinceContrast: Int { distance(since: lastContrastBar) }
    package var barsSinceBreak: Int { distance(since: lastBreakBar) }
    package var barsSinceRelease: Int { distance(since: lastReleaseBar) }

    package mutating func bindLongHorizonIfNeeded(
        rootSeed: UInt64,
        phraseIndex: Int
    ) {
        guard !longHorizon.isBound else { return }
        longHorizon = .initial(
            rootSeed: rootSeed,
            startingPhraseIndex: phraseIndex,
            startingBar: totalBars
        )
    }

    package mutating func record(
        _ plan: AutonomousPhrasePlan,
        rootSeed: UInt64,
        trajectoryDecision: LongHorizonTrajectoryDecision? = nil
    ) -> Bool {
        let updatedLongHorizon: LongHorizonContinuationState
        switch longHorizon.applying(
            plan: plan,
            rootSeed: rootSeed
        ) {
        case let .accepted(updated):
            updatedLongHorizon = updated
        case .preserved:
            return false
        }
        if let trajectoryDecision,
            case let .accepted(corrected) = updatedLongHorizon.applying(
                trajectoryDecision: trajectoryDecision)
        {
            longHorizon = corrected
        } else {
            longHorizon = updatedLongHorizon
        }
        previousPhrase = currentPhrase
        currentPhrase = plan.memoryBars
        recentBars = Array((recentBars + plan.memoryBars).suffix(4))
        sessionBars = Array((sessionBars + plan.memoryBars).suffix(256))
        dramaticArc = Array((dramaticArc + plan.memoryBars).suffix(128))
        totalBars = plan.startBar + plan.barCount
        interlockEvolution = plan.endingInterlockState
        spatialContrast = plan.endingSpatialContrastState
        narrativeEvolution = plan.endingNarrativeState
        harmonicContinuation = plan.endingHarmonicContinuation
        if let character = plan.resolvedBars.first?.performanceCharacter {
            recentPerformanceCharacters = Array(
                (recentPerformanceCharacters + [character]).suffix(2)
            )
        }

        switch plan.kind {
        case .contrast:
            lastContrastBar = plan.startBar
        case .majorBreak:
            lastContrastBar = plan.startBar
            lastBreakBar = plan.startBar
            dramaticArc.removeAll(keepingCapacity: true)
            dramaticArc.append(contentsOf: plan.memoryBars)
        case .energyRelease:
            lastContrastBar = plan.startBar
            lastReleaseBar = plan.startBar
            dramaticArc.removeAll(keepingCapacity: true)
            dramaticArc.append(contentsOf: plan.memoryBars)
            openDebts.removeAll(keepingCapacity: true)
        case .identityReturn:
            lastContrastBar = plan.startBar
            lastIdentityReturnBar = plan.startBar
        case .lock:
            break
        }

        if let debt = plan.openedDebt { openDebts.append(debt) }
        if !plan.paidDebtIDs.isEmpty {
            openDebts.removeAll { plan.paidDebtIDs.contains($0.id) }
        }
        if plan.requestsTopologyMutation { topologyRevision += 1 }
        return true
    }

    private func distance(since bar: Int?) -> Int {
        guard let bar else { return totalBars }
        return max(0, totalBars - bar)
    }
}

package struct PhraseInterestReport: Equatable, Sendable {
    package let pulseClarity: Double
    package let intentionalSpace: Double
    package let responseClosure: Double
    package let structuralTimeliness: Double
    package let identityContinuity: Double
    package let weakPositionCoverage: Double
    package let trailingSideRelationship: Double
    package let overactivityPenalty: Double
    package let overdueDebtCount: Int
    package let score: Double
    package let valid: Bool

    package init(pulseClarity: Double, intentionalSpace: Double,
                responseClosure: Double, structuralTimeliness: Double,
                identityContinuity: Double, weakPositionCoverage: Double,
                trailingSideRelationship: Double, overactivityPenalty: Double,
                overdueDebtCount: Int) {
        let pulseValue = Self.clamp(pulseClarity)
        let spaceValue = Self.clamp(intentionalSpace)
        let responseClosureValue = Self.clamp(responseClosure)
        let timelinessValue = Self.clamp(structuralTimeliness)
        let identityValue = Self.clamp(identityContinuity)
        let weakCoverageValue = Self.clamp(weakPositionCoverage)
        let trailingRelationshipValue = Self.clamp(trailingSideRelationship)
        let overactivityValue = Self.clamp(overactivityPenalty)
        let overdueValue = max(0, overdueDebtCount)
        let computedScore = Self.clamp(
            pulseValue * 0.23 + spaceValue * 0.18 +
            responseClosureValue * 0.15 + timelinessValue * 0.17 +
            identityValue * 0.19 + weakCoverageValue * 0.04 +
            trailingRelationshipValue * 0.04 - overactivityValue * 0.24 -
            Double(overdueValue) * 0.20
        )
        self.pulseClarity = pulseValue
        self.intentionalSpace = spaceValue
        self.responseClosure = responseClosureValue
        self.structuralTimeliness = timelinessValue
        self.identityContinuity = identityValue
        self.weakPositionCoverage = weakCoverageValue
        self.trailingSideRelationship = trailingRelationshipValue
        self.overactivityPenalty = overactivityValue
        self.overdueDebtCount = overdueValue
        score = computedScore
        valid = computedScore >= 0.45 && overdueValue == 0
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}

private func ensembleEventSignature(_ context: EnsembleContext) -> UInt64 {
    var signature = UInt64(context.events.count) &* 0x9E3779B97F4A7C15
    for event in context.events {
        signature ^= SceneDNA.derivedSeed(
            scene: UInt64(event.step + 1),
            domain: UInt64(EnsembleVoice.allCases.firstIndex(of: event.voice) ?? 0) + 1,
            index: event.relocated ? 1 : 0
        )
    }
    return signature
}

private func weightedEventCount(_ context: EnsembleContext) -> Double {
    context.events.reduce(0) { count, event in
        count + (event.voice == .groovePulse ? GroovePulseResolver.eventWeight : 1)
    }
}

package enum LongHorizonPhraseSelectionReason: String, Codable, Sendable {
    case conservativeFallback = "conservative-fallback"
    case minimumHold = "minimum-hold"
    case reservedPayoff = "reserved-payoff"
    case reservedRecall = "reserved-recall"
    case payoffDebtEstablishment = "payoff-debt-establishment"
    case episodeOperator = "episode-operator"
}

package enum LongHorizonPhraseSelectionSchema {
    package static let schemaVersion = 1
    package static let schemaIdentifier = "autotechno-long-horizon-selection.v1"
}

package struct LongHorizonPhraseSelection: Equatable, Codable, Sendable {
    package let schemaVersion: Int
    package let schemaIdentifier: String
    package let episodeID: UInt64?
    package let operatorKind: LongHorizonEpisodeOperator?
    package let phraseKind: AutonomousPhraseKind
    package let reason: LongHorizonPhraseSelectionReason

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case schemaIdentifier
        case episodeID
        case operatorKind
        case phraseKind
        case reason
    }

    package init(
        episodeID: UInt64?,
        operatorKind: LongHorizonEpisodeOperator?,
        phraseKind: AutonomousPhraseKind,
        reason: LongHorizonPhraseSelectionReason
    ) {
        self.schemaVersion = LongHorizonPhraseSelectionSchema.schemaVersion
        self.schemaIdentifier = LongHorizonPhraseSelectionSchema.schemaIdentifier
        self.episodeID = episodeID
        self.operatorKind = operatorKind
        self.phraseKind = phraseKind
        self.reason = reason
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        guard schemaVersion == LongHorizonPhraseSelectionSchema.schemaVersion,
              schemaIdentifier == LongHorizonPhraseSelectionSchema.schemaIdentifier else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaIdentifier,
                in: container,
                debugDescription: "Unsupported long-horizon phrase selection schema"
            )
        }
        let episodeID = try container.decodeIfPresent(UInt64.self, forKey: .episodeID)
        let operatorKind = try container.decodeIfPresent(
            LongHorizonEpisodeOperator.self,
            forKey: .operatorKind
        )
        let phraseKind = try container.decode(AutonomousPhraseKind.self, forKey: .phraseKind)
        let reason = try container.decode(
            LongHorizonPhraseSelectionReason.self,
            forKey: .reason
        )
        guard Self.isConsistent(
            episodeID: episodeID,
            operatorKind: operatorKind,
            phraseKind: phraseKind,
            reason: reason
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .reason,
                in: container,
                debugDescription: "Inconsistent long-horizon phrase selection provenance"
            )
        }
        self.schemaVersion = schemaVersion
        self.schemaIdentifier = schemaIdentifier
        self.episodeID = episodeID
        self.operatorKind = operatorKind
        self.phraseKind = phraseKind
        self.reason = reason
    }

    package static func conservative(
        _ phraseKind: AutonomousPhraseKind
    ) -> LongHorizonPhraseSelection {
        LongHorizonPhraseSelection(
            episodeID: nil,
            operatorKind: nil,
            phraseKind: phraseKind,
            reason: .conservativeFallback
        )
    }

    private static func isConsistent(
        episodeID: UInt64?,
        operatorKind: LongHorizonEpisodeOperator?,
        phraseKind: AutonomousPhraseKind,
        reason: LongHorizonPhraseSelectionReason
    ) -> Bool {
        switch reason {
        case .conservativeFallback:
            return episodeID == nil && operatorKind == nil
        case .minimumHold:
            return episodeID != nil && operatorKind != nil
        case .reservedPayoff:
            return episodeID != nil && operatorKind == .payoff && phraseKind == .lock
        case .reservedRecall:
            return episodeID != nil && operatorKind == .recall && phraseKind == .lock
        case .payoffDebtEstablishment:
            return episodeID != nil && operatorKind == .payoff && phraseKind == .contrast
        case .episodeOperator:
            guard episodeID != nil, let operatorKind else { return false }
            return switch operatorKind {
            case .maintain: phraseKind == .lock
            case .rise: phraseKind == .contrast
            case .recover: phraseKind == .majorBreak
            case .reframe: phraseKind == .contrast || phraseKind == .majorBreak
            case .payoff: phraseKind == .energyRelease
            case .recall: phraseKind == .identityReturn
            }
        }
    }
}

package struct AutonomousPhrasePlan: Equatable, Sendable {
    package let phraseIndex: Int
    package let startBar: Int
    package let barCount: Int
    package let kind: AutonomousPhraseKind
    package let scene: TechnoScene
    package let dna: SceneDNA
    package let resolvedBars: [ResolvedPerformanceBar]
    package let openedDebt: SessionDramaticDebt?
    package let paidDebtIDs: [Int]
    package let requestsTopologyMutation: Bool
    package let interest: PhraseInterestReport
    package let performanceCharacterEvidence: PerformanceCharacterEvidence
    package let endingInterlockState: InterlockEvolutionState
    package let endingSpatialContrastState: SpatialContrastState
    package let endingNarrativeState: NarrativeEvolutionState
    package let incomingHarmonicContinuation: HarmonicContinuationState
    package let phraseComposition: [PhraseCompositionBar]
    package let endingHarmonicContinuation: HarmonicContinuationState
    package let longHorizonSelection: LongHorizonPhraseSelection
    package let longHorizonEnergyCoordination: LongHorizonEnergyCoordination
    package let longHorizonEffectSentence: LongHorizonEffectSentence?

    package init(phraseIndex: Int, startBar: Int, barCount: Int,
                 kind: AutonomousPhraseKind, scene: TechnoScene, dna: SceneDNA,
                 resolvedBars: [ResolvedPerformanceBar], openedDebt: SessionDramaticDebt?,
                 paidDebtIDs: [Int], requestsTopologyMutation: Bool,
                 interest: PhraseInterestReport,
                 endingInterlockState: InterlockEvolutionState,
                 endingSpatialContrastState: SpatialContrastState = SpatialContrastState(),
                 endingNarrativeState: NarrativeEvolutionState = NarrativeEvolutionState(),
                 harmonicContinuation: HarmonicContinuationState = HarmonicContinuationState(),
                 longHorizonSelection: LongHorizonPhraseSelection? = nil,
                 longHorizonEnergyCoordination: LongHorizonEnergyCoordination? = nil) {
        self.phraseIndex = phraseIndex
        self.startBar = startBar
        self.barCount = barCount
        self.kind = kind
        self.scene = scene
        self.dna = dna
        self.resolvedBars = resolvedBars
        self.openedDebt = openedDebt
        self.paidDebtIDs = paidDebtIDs
        self.requestsTopologyMutation = requestsTopologyMutation
        self.interest = interest
        performanceCharacterEvidence = PerformanceCharacterEvidence(
            resolvedBars: resolvedBars,
            kind: kind,
            paidDebtIDs: paidDebtIDs
        )
        self.endingInterlockState = endingInterlockState
        self.endingSpatialContrastState = endingSpatialContrastState
        self.endingNarrativeState = endingNarrativeState
        incomingHarmonicContinuation = harmonicContinuation
        phraseComposition = PhraseCompositionResolver.resolve(
            scene: scene,
            dna: dna,
            kind: kind,
            resolvedBars: resolvedBars,
            harmonicContinuation: harmonicContinuation
        )
        endingHarmonicContinuation = HarmonicContinuationState(
            voices: phraseComposition.compactMap(\.padVoicing).last?.voices ??
                harmonicContinuation.voices
        )
        let resolvedSelection = longHorizonSelection.flatMap {
            $0.phraseKind == kind ? $0 : nil
        } ?? .conservative(kind)
        self.longHorizonSelection = resolvedSelection
        let resolvedCoordination = longHorizonEnergyCoordination ?? .neutral(
            phraseIndex: self.phraseIndex,
            startBar: self.startBar,
            phraseKind: kind,
            selectionReason: resolvedSelection.reason
        )
        self.longHorizonEnergyCoordination = resolvedCoordination.isConsistent(
            phraseIndex: self.phraseIndex,
            startBar: self.startBar,
            phraseKind: kind,
            selection: resolvedSelection
        ) ? resolvedCoordination : .neutral(
            phraseIndex: self.phraseIndex,
            startBar: self.startBar,
            phraseKind: kind,
            selectionReason: resolvedSelection.reason
        )
        longHorizonEffectSentence = LongHorizonEffectSentence.resolving(
            phraseIndex: self.phraseIndex,
            phraseKind: kind,
            resolvedBars: self.resolvedBars
        )
    }

    package var memoryBars: [MusicalMemoryBar] {
        resolvedBars.map { resolved in
            let bar = resolved.performance
            let context = resolved.ensemble
            return MusicalMemoryBar(
                absoluteBar: bar.bar,
                phraseIndex: phraseIndex,
                section: bar.section,
                tension: bar.tension,
                roles: bar.roles,
                transformations: bar.transformations,
                eventSignature: ensembleEventSignature(context),
                activity: weightedEventCount(context) / 16,
                repetition: bar.transformations.contains(.`repeat`) ||
                    bar.transformations.contains(.restore) ? 1 : 0,
                density: Double(bar.roles.count) / Double(PerformanceRole.allCases.count)
            )
        }
    }
}

package struct AutonomousSessionState: Equatable, Sendable {
    package let rootSeed: UInt64
    package let identitySeed: UInt64
    package let identityDNA: SceneDNA
    package var phraseIndex: Int
    package var intent: MusicalIntent
    package var memory: TemporalMusicalMemory
    /// Reduced, versioned evidence/decision continuation. Signal-domain
    /// observations remain in AutoTechnoDSP; only the selected preparation's
    /// reduced provenance crosses the phrase boundary with the musical state.
    package var quality: QualityContinuationState
    /// The sole committed live master-headroom continuation. A pending
    /// observation or proposal cannot mutate this value.
    package let liveMasterHeadroom: LiveMasterHeadroomContinuationState

    package init(rootSeed: UInt64 = AutonomousSessionDirector.defaultSeed, phraseIndex: Int = 0,
                intent: MusicalIntent = MusicalIntent(),
                memory: TemporalMusicalMemory = TemporalMusicalMemory(),
                quality: QualityContinuationState = QualityContinuationState(),
                liveMasterHeadroom: LiveMasterHeadroomContinuationState =
                    LiveMasterHeadroomContinuationState()) {
        let normalizedIntent = intent.preservingCorrelations()
        self.rootSeed = rootSeed
        identitySeed = rootSeed &+ 17
        identityDNA = SceneDNA(scene: TechnoScene(
            intent: normalizedIntent, seed: rootSeed &+ 17, bpm: AutonomousSessionDirector.bpm
        ))
        self.phraseIndex = max(0, phraseIndex)
        self.intent = normalizedIntent
        var boundMemory = memory
        boundMemory.bindLongHorizonIfNeeded(
            rootSeed: rootSeed,
            phraseIndex: self.phraseIndex
        )
        self.memory = boundMemory
        self.quality = quality
        self.liveMasterHeadroom = liveMasterHeadroom
    }

    private init(
        rootSeed: UInt64,
        identitySeed: UInt64,
        identityDNA: SceneDNA,
        phraseIndex: Int,
        intent: MusicalIntent,
        memory: TemporalMusicalMemory,
        quality: QualityContinuationState,
        liveMasterHeadroom: LiveMasterHeadroomContinuationState
    ) {
        self.rootSeed = rootSeed
        self.identitySeed = identitySeed
        self.identityDNA = identityDNA
        self.phraseIndex = max(0, phraseIndex)
        self.intent = intent.preservingCorrelations()
        self.memory = memory
        self.quality = quality
        self.liveMasterHeadroom = liveMasterHeadroom
    }

    /// Advances authored planning state without accepting prepared evidence.
    /// Runtime commit sites must use the value-returning atomic overload below.
    package mutating func advancePlanning(using plan: AutonomousPhrasePlan) {
        self = advance(
            using: plan,
            quality: quality,
            liveMasterHeadroom: liveMasterHeadroom,
            longHorizonDecision: nil
        )
    }

    /// The accepted prepared product advances musical, quality, and live
    /// controller continuation as one deterministic value. Callers cannot
    /// partially commit one continuation while leaving another behind.
    package func advance(
        using plan: AutonomousPhrasePlan,
        quality acceptedQuality: QualityContinuationState,
        liveMasterHeadroom acceptedLiveMasterHeadroom:
            LiveMasterHeadroomContinuationState,
        longHorizonDecision: LongHorizonTrajectoryDecision? = nil
    ) -> AutonomousSessionState {
        guard acceptedLiveMasterHeadroom == liveMasterHeadroom ||
                acceptedLiveMasterHeadroom.isImmediateSuccessor(of: liveMasterHeadroom) else {
            return self
        }
        guard plan.phraseIndex < Int.max else { return self }
        var nextMemory = memory
        guard nextMemory.record(
            plan,
            rootSeed: rootSeed,
            trajectoryDecision: longHorizonDecision
        ) else { return self }
        return AutonomousSessionState(
            rootSeed: rootSeed,
            identitySeed: identitySeed,
            identityDNA: identityDNA,
            phraseIndex: plan.phraseIndex + 1,
            intent: plan.scene.musicalIntent,
            memory: nextMemory,
            quality: acceptedQuality,
            liveMasterHeadroom: acceptedLiveMasterHeadroom
        )
    }
}

package enum PhraseInterestEvaluator {
    package static func evaluate(resolvedBars: [ResolvedPerformanceBar],
                                kind: AutonomousPhraseKind, memory: TemporalMusicalMemory,
                                identityPreserved: Bool) -> PhraseInterestReport {
        let bars = resolvedBars.map(\.performance)
        let ensemble = resolvedBars.map(\.ensemble)
        let pulseBars = ensemble.filter { context in
            !context.kickAnchors.isEmpty && context.kickAnchors.allSatisfy { anchor in
                context.events.contains { $0.voice == .kick && $0.step == anchor }
            } && context.events.filter { $0.voice == .bass }.allSatisfy {
                !context.kickAnchors.contains($0.step)
            }
        }.count
        let pulseClarity = ensemble.isEmpty ? 0 : Double(pulseBars) / Double(ensemble.count)
        let averageEvents = ensemble.isEmpty ? 16 :
            ensemble.reduce(0) { $0 + weightedEventCount($1) } / Double(ensemble.count)
        let intentionalSpace = min(1, max(0, 1 - averageEvents / 16))
        let overactivityPenalty = min(1, max(0, (averageEvents - 9) / 7))
        let hasMotif = ensemble.contains { $0.events.contains { $0.voice == .motif } }
        let hasResponse = ensemble.contains { $0.events.contains { $0.voice == .response } }
        let responseClosure = !hasMotif || hasResponse || kind == .majorBreak ? 1 : 0.35
        let structuralKind = kind == .energyRelease || kind == .majorBreak || kind == .identityReturn
        let hasMacroResolution = resolvedBars.contains {
            $0.arrangementGesture == .structuralMarker && ($0.performance.bar + 1).isMultiple(of: 16)
        }
        let timely = structuralKind ? hasMacroResolution :
            (kind == .contrast ||
             (memory.barsSinceContrast < 24 && memory.barsSinceBreak < 96 && memory.barsSinceRelease < 128))
        let structuralTimeliness = timely ? 1 : 0.20
        var expectedWeakPositions = 0
        var matchedWeakPositions = 0
        var unexpectedWeakPositions = 0
        var leadingStrength = 0.0
        var trailingStrength = 0.0
        var leadingCount = 0
        var trailingCount = 0
        for resolved in resolvedBars {
            let performance = resolved.performance
            let expectsPulses = kind != .majorBreak &&
                performance.roles.contains(.percussion)
            let expected = expectsPulses ? GroovePulseResolver.pattern(
                stage: WeakSixteenthStage(absoluteBar: performance.bar),
                gesture: resolved.arrangementGesture,
                macroEnding: (performance.bar + 1).isMultiple(of: 16)
            ).map(\.0) : []
            let actual = resolved.groovePulses.map(\.step)
            let expectedSet = Set(expected)
            expectedWeakPositions += expectedSet.count
            matchedWeakPositions += actual.filter(expectedSet.contains).count
            unexpectedWeakPositions += actual.filter { !expectedSet.contains($0) }.count
            for articulation in resolved.groovePulses {
                switch articulation.pulseClass {
                case .leadingWeak:
                    leadingStrength += articulation.intensity
                    leadingCount += 1
                case .trailingWeak:
                    trailingStrength += articulation.intensity
                    trailingCount += 1
                case .downbeat, .upbeat:
                    break
                }
            }
        }
        let weakPositionCoverage: Double
        if expectedWeakPositions == 0 {
            weakPositionCoverage = unexpectedWeakPositions == 0 ? 1 : 0
        } else {
            weakPositionCoverage = min(1, max(0,
                Double(matchedWeakPositions - unexpectedWeakPositions) /
                    Double(expectedWeakPositions)
            ))
        }
        let trailingSideRelationship: Double
        if trailingCount == 0 {
            trailingSideRelationship = leadingCount == 0 ? 1 : 0
        } else if leadingCount == 0 {
            trailingSideRelationship = 1
        } else {
            let leadingAverage = leadingStrength / Double(leadingCount)
            let trailingAverage = trailingStrength / Double(trailingCount)
            trailingSideRelationship = trailingAverage > leadingAverage ? 1 : 0
        }
        let phraseEnd = (bars.last?.bar ?? memory.totalBars) + 1
        let overdue = memory.openDebts.filter { $0.dueByBar < phraseEnd && kind != .energyRelease }.count
        return PhraseInterestReport(
            pulseClarity: pulseClarity,
            intentionalSpace: intentionalSpace,
            responseClosure: responseClosure,
            structuralTimeliness: structuralTimeliness,
            identityContinuity: identityPreserved ? 1 : 0,
            weakPositionCoverage: weakPositionCoverage,
            trailingSideRelationship: trailingSideRelationship,
            overactivityPenalty: overactivityPenalty,
            overdueDebtCount: overdue
        )
    }
}

/// Pure, deterministic session policy. It produces one complete immutable
/// phrase; rendering and calibrated evaluation live in AutoTechnoDSP.
package struct AutonomousSessionDirector: Equatable, Sendable {
    package static let bpm = 130.0
    package static let defaultSeed: UInt64 = 48_291
    package let rootSeed: UInt64

    package init(rootSeed: UInt64 = Self.defaultSeed) {
        self.rootSeed = rootSeed
    }

    package func initialState() -> AutonomousSessionState {
        AutonomousSessionState(rootSeed: rootSeed)
    }

    /// Resolves the one canonical phrase proposed at this musical boundary.
    /// Quality evaluation may correct this same plan once, but it never asks
    /// the director for a parallel substitute.
    package func plan(from state: AutonomousSessionState) -> AutonomousPhrasePlan {
        let selection = nextSelection(state: state)
        return makePlan(
            state: state,
            kind: selection.phraseKind,
            longHorizonSelection: selection
        )
    }

    private func nextSelection(
        state: AutonomousSessionState
    ) -> LongHorizonPhraseSelection {
        let conservativeKind = conservativeNextKind(state: state)
        let continuation = state.memory.longHorizon
        guard rootSeed == state.rootSeed,
              continuation.isBound,
              continuation.rootSeed == state.rootSeed,
              continuation.nextExpectedPhraseIndex == state.phraseIndex,
              continuation.nextExpectedBar == state.memory.totalBars else {
            return .conservative(conservativeKind)
        }
        let episode = continuation.currentEpisode
        if episode.operatorKind == .recover,
            episode.startedAtBar == state.memory.totalBars,
            continuation.lastTrajectoryDecision?.action == .recover,
            continuation.lastTrajectoryDecision?.targetPhraseIndex == state.phraseIndex,
            continuation.lastTrajectoryDecision?.targetBar == state.memory.totalBars
        {
            return LongHorizonPhraseSelection(
                episodeID: episode.id,
                operatorKind: episode.operatorKind,
                phraseKind: .majorBreak,
                reason: .episodeOperator
            )
        }
        if state.memory.totalBars < episode.minimumHoldUntilBar {
            if episode.operatorKind == .payoff,
               conservativeKind == .energyRelease {
                return LongHorizonPhraseSelection(
                    episodeID: episode.id,
                    operatorKind: episode.operatorKind,
                    phraseKind: .lock,
                    reason: .reservedPayoff
                )
            }
            if episode.operatorKind == .recall,
               conservativeKind == .identityReturn {
                return LongHorizonPhraseSelection(
                    episodeID: episode.id,
                    operatorKind: episode.operatorKind,
                    phraseKind: .lock,
                    reason: .reservedRecall
                )
            }
            return LongHorizonPhraseSelection(
                episodeID: episode.id,
                operatorKind: episode.operatorKind,
                phraseKind: conservativeKind,
                reason: .minimumHold
            )
        }

        if episode.operatorKind == .payoff,
           state.memory.openDebts.isEmpty {
            return LongHorizonPhraseSelection(
                episodeID: episode.id,
                operatorKind: episode.operatorKind,
                phraseKind: .contrast,
                reason: .payoffDebtEstablishment
            )
        }
        let selectedKind: AutonomousPhraseKind = switch episode.operatorKind {
        case .maintain: .lock
        case .rise: .contrast
        case .recover: .majorBreak
        case .reframe:
            episode.startEnergy.roleDensity >= 0.5 ? .majorBreak : .contrast
        case .payoff: .energyRelease
        case .recall: .identityReturn
        }
        return LongHorizonPhraseSelection(
            episodeID: episode.id,
            operatorKind: episode.operatorKind,
            phraseKind: selectedKind,
            reason: .episodeOperator
        )
    }

    private func conservativeNextKind(
        state: AutonomousSessionState
    ) -> AutonomousPhraseKind {
        // Each target is fixed for the life of its current interval. If it
        // changed at every phrase boundary, a moving target could postpone a
        // promised structural event indefinitely.
        let releaseTarget = 64 + Int(thresholdSeed(
            state: state, domain: 0xE1EA5E, anchor: state.memory.lastReleaseBar
        ) % 65)
        let breakTarget = 48 + Int(thresholdSeed(
            state: state, domain: 0xB2EA4, anchor: state.memory.lastBreakBar
        ) % 49)
        let contrastTarget = 8 + Int(thresholdSeed(
            state: state, domain: 0xC0472A57, anchor: state.memory.lastContrastBar
        ) % 17)
        if state.memory.barsSinceRelease >= releaseTarget { return .energyRelease }
        if state.memory.barsSinceBreak >= breakTarget { return .majorBreak }
        if state.memory.barsSinceContrast >= contrastTarget { return .contrast }
        if state.phraseIndex > 0 && state.phraseIndex.isMultiple(of: 5) { return .identityReturn }
        return .lock
    }

    private func makePlan(
        state: AutonomousSessionState,
        kind: AutonomousPhraseKind,
        longHorizonSelection: LongHorizonPhraseSelection
    ) -> AutonomousPhrasePlan {
        let start = state.memory.totalBars
        let energyCoordination = LongHorizonEnergyCoordination.resolving(
            state: state,
            selection: longHorizonSelection
        )
        let energyTarget = energyCoordination.target
        let baseLength = 4 + Int(seed(
            state: state,
            domain: 0xF4A5E,
            index: 0
        ) % 13)
        let structuralKind = kind == .majorBreak || kind == .energyRelease || kind == .identityReturn
        let barsToMacroBoundary = 16 - (start % 16)
        // Structural phrases always contain the next global sixteen-bar
        // resolution point while retaining the adaptive four-to-sixteen-bar
        // phrase vocabulary.
        let length = structuralKind ? max(baseLength, barsToMacroBoundary) : baseLength
        let mutationAmount: Double
        switch kind {
        case .lock: mutationAmount = 0.035
        case .contrast: mutationAmount = 0.13
        case .majorBreak: mutationAmount = 0.10
        case .energyRelease: mutationAmount = 0.07
        case .identityReturn: mutationAmount = 0.045
        }
        let phraseSeed = seed(state: state, domain: 0x51A7E, index: 0)
        let intent = MusicalIntent.mutated(state.intent, seed: phraseSeed, amount: mutationAmount)
            .preservingCorrelations()
        let scene = TechnoScene(intent: intent, seed: state.identitySeed, bpm: Self.bpm)
        // Rhythm, motif, tonal centre and timbral family are session identity.
        // Phrase intentions may reinterpret them but never silently replace
        // them with an independently generated scene identity.
        let dna = state.identityDNA
        let section = section(for: kind)
        let character = Self.canonicalPerformanceCharacter(
            kind: kind,
            rootSeed: state.rootSeed,
            phraseIndex: state.phraseIndex,
            recentPerformanceCharacters: state.memory.recentPerformanceCharacters,
            timbralMotionIntent: energyTarget.timbralMotionIntent
        )
        let focusRole = focus(kind: kind, seed: phraseSeed)
        var resolvedBars: [ResolvedPerformanceBar] = []
        resolvedBars.reserveCapacity(length)
        var interlockState = state.memory.interlockEvolution
        var spatialContrastState = state.memory.spatialContrast
        let narrativeTrajectory = narrativePresenceTrajectory(
            initialPresence: state.memory.narrativeEvolution.protagonistPresence,
            settlementPending: state.memory.narrativeEvolution.releaseSettlementPending,
            kind: kind,
            startBar: start,
            length: length,
            relationship: energyTarget.protagonistPresence
        )
        let baselineSupportingRoles = kind == .majorBreak
            ? [PerformanceRole.atmosphere]
            : state.memory.narrativeEvolution.activeSupportingRoles
        var activeSupportingRoles = coordinatedSupportingRoles(
            baselineSupportingRoles,
            kind: kind,
            focus: focusRole,
            target: energyTarget
        )

        for localBar in 0..<length {
            let progress = length == 1 ? 1 : Double(localBar) / Double(length - 1)
            let tension = tension(kind: kind, progress: progress, prior: state.memory.currentPhrase.last?.tension ?? 0.42)
            let transformations = transformations(
                kind: kind,
                localBar: localBar,
                length: length,
                seed: phraseSeed,
                relationship: energyTarget.timbralMotionIntent
            )
            let absoluteBar = start + localBar
            let proposedRoles = roles(
                kind: kind,
                focus: focusRole,
                localBar: localBar,
                length: length,
                target: energyTarget
            )
            let narrativeStart = localBar == 0
                ? state.memory.narrativeEvolution.protagonistPresence
                : narrativeTrajectory.endpoints[localBar - 1]
            let narrative = NarrativeArticulation(
                presenceStart: narrativeStart,
                presenceEnd: narrativeTrajectory.endpoints[localBar],
                activeSupportingRoles: activeSupportingRoles
            )
            let resolvedRoles = narrativeResolvedRoles(
                proposed: proposedRoles,
                activeSupportingRoles: activeSupportingRoles
            )
            if absoluteBar > 0, absoluteBar.isMultiple(of: 16) {
                let chapterEntropy = SceneDNA.derivedSeed(
                    scene: state.rootSeed,
                    domain: 0x1A7E2C10 ^ UInt64(AutonomousPhraseKind.allCases.firstIndex(of: kind) ?? 0),
                    index: absoluteBar / 16
                )
                interlockState = interlockState.advancing(for: kind, entropy: chapterEntropy)
            }
            let macroResolution = (absoluteBar + 1).isMultiple(of: 16)
            let signature: SignatureEvent?
            if macroResolution {
                switch kind {
                case .energyRelease: signature = .displacedKickRecovery
                case .identityReturn: signature = .alteredMotifAnswer
                case .majorBreak: signature = .harmonicShadow
                case .lock, .contrast: signature = nil
                }
            } else {
                signature = nil
            }
            let contour = accentContour(dna: dna, absoluteBar: absoluteBar, progress: progress,
                                        release: kind == .energyRelease)
            let bar = PerformanceBar(
                bar: absoluteBar,
                phrase: state.phraseIndex,
                localBar: localBar,
                phraseLength: length,
                section: section,
                tension: tension,
                roles: resolvedRoles,
                transformations: transformations,
                signatureEvent: signature,
                eventSeed: SceneDNA.derivedSeed(scene: phraseSeed, domain: 0xBA2, index: localBar),
                accentContour: contour
            )
            let gesture = arrangementGesture(kind: kind, absoluteBar: absoluteBar)
            let gear = percussionGear(
                absoluteBar: absoluteBar,
                relationship: energyTarget.percussionActivity
            )
            let foundation = foundationResolution(
                character: character,
                kind: kind,
                localBar: localBar,
                length: length,
                gesture: gesture,
                relationship: energyTarget.foundationAuthority
            )
            let ensemble = Self.ensemblePlan(
                dna: dna, bar: bar, focus: focusRole,
                release: kind == .energyRelease, kind: kind,
                character: character,
                foundationBehavior: foundation.behavior,
                companion: foundation.companion,
                gear: gear, gesture: gesture
            )
            let modalPercussionArticulations = ModalPercussionResolver.foundationArticulations(
                ensemble: ensemble,
                dna: dna,
                performance: bar,
                character: character,
                gesture: gesture,
                behavior: foundation.behavior
            )
            let groovePulses = GroovePulseResolver.articulations(
                from: ensemble,
                absoluteBar: absoluteBar,
                swingPercent: dna.rhythm.swingPercent,
                percussionGear: gear,
                eventSeed: bar.eventSeed
            )
            let closedHatDecayArticulations = ClosedHatDecayResolver.articulations(from: ensemble)
            let upperPercussionTailArticulations =
                UpperPercussionTailResolver.articulations(
                    from: ensemble,
                    phraseKind: kind,
                    performanceCharacter: character
                )
            let percussionEchoTexture = PercussionEchoTextureResolver.articulation(
                ensemble: ensemble,
                kind: kind,
                character: character,
                gesture: gesture,
                absoluteBar: absoluteBar
            )
            let echoEnabled = pulseEchoEnabled(
                scene: scene, bar: bar, kind: kind,
                companion: foundation.companion, gesture: gesture,
                relationship: energyTarget.transitionExpectation
            )
            let spatialResolution = spatialContrastState.resolving(
                ensemble: ensemble,
                kind: kind,
                gesture: gesture,
                absoluteBar: absoluteBar,
                relationship: energyTarget.spatialDistance
            )
            let spatialContrast = spatialResolution.0
            spatialContrastState = spatialResolution.1
            resolvedBars.append(ResolvedPerformanceBar(
                performance: bar,
                ensemble: ensemble,
                arrangementGesture: gesture,
                percussionGear: gear,
                performanceCharacter: character,
                foundationBehavior: foundation.behavior,
                foundationCompanion: foundation.companion,
                pulseEchoEnabled: echoEnabled,
                interlockChapter: interlockState.currentChapter,
                groovePulses: groovePulses,
                closedHatDecayArticulations: closedHatDecayArticulations,
                upperPercussionTailArticulations:
                    upperPercussionTailArticulations,
                modalPercussionArticulations: modalPercussionArticulations,
                spatialContrast: spatialContrast,
                narrative: narrative,
                percussionEchoTexture: percussionEchoTexture,
                harmonicDisclosureRelationship:
                    energyTarget.harmonicDisclosure,
                kickMorphology: KickMorphologyResolver.articulation(
                    sessionSeed: scene.seed,
                    absoluteBar: absoluteBar
                )
            ))
            activeSupportingRoles = narrativeSupportingRolesAfterBoundary(
                current: activeSupportingRoles,
                proposed: proposedRoles,
                focus: focusRole,
                kind: kind,
                gesture: gesture,
                direction: narrative.direction,
                absoluteBar: absoluteBar
            )
        }

        let openedDebt: SessionDramaticDebt?
        if kind == .contrast || kind == .majorBreak {
            openedDebt = SessionDramaticDebt(
                id: state.phraseIndex,
                openedAtBar: start,
                dueByBar: start + 128,
                source: kind
            )
        } else {
            openedDebt = nil
        }
        let paidDebtIDs = kind == .energyRelease ? state.memory.openDebts.map(\.id) : []
        resolvedBars = FoundationRhythmicRelationResolver.resolve(
            resolvedBars: resolvedBars,
            kind: kind,
            dna: dna
        )
        resolvedBars = KickSyntaxResolver.resolve(
            resolvedBars: resolvedBars,
            kind: kind,
            paidDebtIDs: paidDebtIDs
        )
        let interest = PhraseInterestEvaluator.evaluate(
            resolvedBars: resolvedBars,
            kind: kind,
            memory: state.memory,
            identityPreserved: scene.seed == state.identitySeed
        )
        let endingNarrativeState = NarrativeEvolutionState(
            protagonistPresence: narrativeTrajectory.endpoints.last ??
                state.memory.narrativeEvolution.protagonistPresence,
            activeSupportingRoles: activeSupportingRoles,
            releaseSettlementPending: narrativeTrajectory.settlementPending
        )
        return AutonomousPhrasePlan(
            phraseIndex: state.phraseIndex,
            startBar: start,
            barCount: length,
            kind: kind,
            scene: scene,
            dna: dna,
            resolvedBars: resolvedBars,
            openedDebt: openedDebt,
            paidDebtIDs: paidDebtIDs,
            requestsTopologyMutation: state.phraseIndex > 0 &&
                (kind == .contrast || kind == .majorBreak),
            interest: interest,
            endingInterlockState: interlockState,
            endingSpatialContrastState: spatialContrastState,
            endingNarrativeState: endingNarrativeState,
            harmonicContinuation: state.memory.harmonicContinuation,
            longHorizonSelection: longHorizonSelection,
            longHorizonEnergyCoordination: energyCoordination
        )
    }

    private func section(for kind: AutonomousPhraseKind) -> SectionKind {
        switch kind {
        case .lock: .groove
        case .contrast: .build
        case .majorBreak: .breakdown
        case .energyRelease, .identityReturn: .returnSection
        }
    }

    package static func canonicalPerformanceCharacter(
        kind: AutonomousPhraseKind,
        rootSeed: UInt64,
        phraseIndex: Int,
        recentPerformanceCharacters: [PerformanceCharacter],
        timbralMotionIntent: LongHorizonEnergyRelationship = .hold
    ) -> PerformanceCharacter {
        guard kind != .identityReturn else { return .hypnoticLock }
        let preferred: [PerformanceCharacter] = switch kind {
        case .lock: [.hypnoticLock, .melodicGlow]
        case .contrast: [.acidPressure, .brokenSuspension, .melodicGlow]
        case .majorBreak: [.brokenSuspension, .ambientDrift]
        case .energyRelease: [.peakDrive, .acidPressure]
        case .identityReturn: [.hypnoticLock]
        }
        let recent = Set(recentPerformanceCharacters)
        let unrepeated = preferred.filter { !recent.contains($0) }
        let choices = unrepeated.isEmpty ? preferred : unrepeated
        let phraseSeed = SceneDNA.derivedSeed(
            scene: rootSeed,
            domain: 0x51A7E ^ UInt64(phraseIndex + 1),
            index: 0
        )
        let baseline = choices[Int(phraseSeed % UInt64(choices.count))]
        guard timbralMotionIntent != .hold else { return baseline }
        switch timbralMotionIntent {
        case .hold:
            return baseline
        case .lower:
            return switch kind {
            case .lock: .hypnoticLock
            case .contrast: .brokenSuspension
            case .majorBreak: .ambientDrift
            case .energyRelease: .acidPressure
            case .identityReturn: .hypnoticLock
            }
        case .raise:
            return switch kind {
            case .lock: .melodicGlow
            case .contrast: .acidPressure
            case .majorBreak: .brokenSuspension
            case .energyRelease: .peakDrive
            case .identityReturn: .hypnoticLock
            }
        case .change:
            return preferred.first(where: { $0 != baseline }) ?? baseline
        case .home:
            return kind == .identityReturn ? .hypnoticLock : baseline
        }
    }

    private func focus(kind: AutonomousPhraseKind, seed: UInt64) -> PerformanceRole {
        switch kind {
        case .majorBreak: return .atmosphere
        case .energyRelease: return .foundation
        case .identityReturn: return .motif
        case .contrast: return .percussion
        case .lock:
            let palette: [PerformanceRole] = [.foundation, .percussion, .motif, .atmosphere]
            return palette[Int(seed % UInt64(palette.count))]
        }
    }

    private func narrativePresenceTrajectory(initialPresence: Double,
                                             settlementPending: Bool,
                                             kind: AutonomousPhraseKind,
                                             startBar: Int,
                                             length: Int,
                                             relationship: LongHorizonEnergyRelationship = .hold) ->
        (endpoints: [Double], settlementPending: Bool) {
        guard length > 0 else { return ([], settlementPending) }

        if kind == .energyRelease {
            let peakIndex = (0..<length).first {
                (startBar + $0 + 1).isMultiple(of: 16)
            } ?? (length - 1)
            var endpoints: [Double] = []
            endpoints.reserveCapacity(length)
            for index in 0...peakIndex {
                let progress = Double(index + 1) / Double(peakIndex + 1)
                endpoints.append(initialPresence + (0.90 - initialPresence) * progress)
            }
            let settlingBars = length - peakIndex - 1
            if settlingBars > 0 {
                for settlingIndex in 1...settlingBars {
                    let progress = Double(settlingIndex) / Double(settlingBars)
                    endpoints.append(0.90 + (0.60 - 0.90) * progress)
                }
            }
            return coordinatedNarrativeTrajectory(
                endpoints: endpoints,
                settlementPending: settlingBars == 0,
                initialPresence: initialPresence,
                relationship: relationship
            )
        }

        let target: Double
        switch kind {
        case .lock: target = 0.56
        case .contrast: target = 0.76
        case .majorBreak: target = 0.20
        case .identityReturn: target = 0.58
        case .energyRelease: target = 0.60
        }

        var endpoints: [Double] = []
        endpoints.reserveCapacity(length)
        if settlementPending {
            endpoints.append(0.60)
            let remainingBars = length - 1
            if remainingBars > 0 {
                for index in 1..<length {
                    let progress = Double(index) / Double(remainingBars)
                    endpoints.append(0.60 + (target - 0.60) * progress)
                }
            }
        } else {
            for index in 0..<length {
                let progress = Double(index + 1) / Double(length)
                endpoints.append(initialPresence + (target - initialPresence) * progress)
            }
        }
        return coordinatedNarrativeTrajectory(
            endpoints: endpoints,
            settlementPending: false,
            initialPresence: initialPresence,
            relationship: relationship
        )
    }

    private func coordinatedNarrativeTrajectory(
        endpoints: [Double],
        settlementPending: Bool,
        initialPresence: Double,
        relationship: LongHorizonEnergyRelationship
    ) -> (endpoints: [Double], settlementPending: Bool) {
        guard relationship != .hold, !endpoints.isEmpty else {
            return (endpoints, settlementPending)
        }
        let changeDirection = initialPresence >= 0.5 ? -1.0 : 1.0
        var previous = min(0.92, max(0.12, initialPresence))
        let coordinated = endpoints.enumerated().map { index, endpoint in
            let progress = Double(index + 1) / Double(endpoints.count)
            let value: Double = switch relationship {
            case .hold:
                endpoint
            case .lower:
                endpoint - 0.12 * progress
            case .raise:
                endpoint + 0.12 * progress
            case .change:
                endpoint + changeDirection * 0.10 * progress
            case .home:
                endpoint + (0.58 - endpoint) * progress
            }
            let bounded = min(0.92, max(0.12, value))
            let slewed = min(previous + 0.16, max(previous - 0.16, bounded))
            previous = slewed
            return slewed
        }
        return (coordinated, settlementPending)
    }

    private func narrativeResolvedRoles(proposed: [PerformanceRole],
                                        activeSupportingRoles: [PerformanceRole])
        -> [PerformanceRole] {
        proposed.filter { role in
            switch role {
            case .foundation, .motif, .transition:
                return true
            case .percussion, .response, .atmosphere:
                return activeSupportingRoles.contains(role)
            }
        }
    }

    private func narrativeSupportingRolesAfterBoundary(
        current: [PerformanceRole], proposed: [PerformanceRole],
        focus: PerformanceRole, kind: AutonomousPhraseKind,
        gesture: ArrangementGesture, direction: NarrativeDirection,
        absoluteBar: Int
    ) -> [PerformanceRole] {
        if kind == .majorBreak {
            return proposed.contains(.atmosphere) ? [.atmosphere] : []
        }
        guard (absoluteBar + 1).isMultiple(of: 4) else { return current }

        if kind == .identityReturn, (absoluteBar + 1).isMultiple(of: 16) {
            return NarrativeArticulation.supportingRoles(current + [.percussion])
        }

        if direction == .receding, gesture == .turnaround, !current.isEmpty {
            let removalPriority: [PerformanceRole] = [.atmosphere, .response, .percussion]
            let selected = removalPriority.first {
                current.contains($0) && $0 != focus
            } ?? removalPriority.first(where: current.contains)
            guard let selected else { return current }
            return NarrativeArticulation.supportingRoles(
                current.filter { $0 != selected }
            )
        }

        let mayAdd = direction == .emerging || kind == .contrast || kind == .energyRelease
        guard mayAdd, gesture != .minimalize else { return current }
        let supportRoles: [PerformanceRole] = [.percussion, .response, .atmosphere]
        var admissionPriority: [PerformanceRole] = []
        if supportRoles.contains(focus) { admissionPriority.append(focus) }
        admissionPriority += supportRoles.filter { $0 != focus }
        guard let selected = admissionPriority.first(where: {
            proposed.contains($0) && !current.contains($0)
        }) else { return current }
        return NarrativeArticulation.supportingRoles(current + [selected])
    }

    private func roles(kind: AutonomousPhraseKind, focus: PerformanceRole,
                       localBar: Int, length: Int,
                       target: LongHorizonEnergyTarget = .neutral) -> [PerformanceRole] {
        var result: [PerformanceRole] = [.foundation]
        func append(_ role: PerformanceRole) {
            if !result.contains(role) && result.count < 4 { result.append(role) }
        }
        append(focus)
        switch kind {
        case .lock:
            append(.percussion); append(.motif)
        case .contrast:
            append(.percussion); append(.motif); append(localBar >= length / 2 ? .response : .transition)
        case .majorBreak:
            append(.atmosphere)
            if localBar == length - 1 { append(.transition) }
        case .energyRelease:
            append(.percussion); append(.motif); append(.response)
        case .identityReturn:
            append(.motif); append(.atmosphere)
        }
        guard !target.isNeutral else { return result }

        let baseline = result
        let desiredCount: Int = switch target.roleDensity {
        case .lower: max(2, baseline.count - 1)
        case .raise: min(4, baseline.count + 1)
        case .hold, .change: baseline.count
        case .home: min(3, max(2, baseline.count))
        }
        func set(_ role: PerformanceRole, included: Bool) {
            if included {
                if !result.contains(role) { result.append(role) }
            } else if role != .foundation && role != focus {
                result.removeAll { $0 == role }
            }
        }
        func coordinate(
            _ role: PerformanceRole,
            relationship: LongHorizonEnergyRelationship,
            home: Bool,
            active: Bool = true
        ) {
            guard active else { return }
            switch relationship {
            case .hold: break
            case .lower: set(role, included: false)
            case .raise: set(role, included: true)
            case .change: set(role, included: !result.contains(role))
            case .home: set(role, included: home)
            }
        }
        coordinate(
            .percussion,
            relationship: target.percussionActivity,
            home: false
        )
        coordinate(
            .atmosphere,
            relationship: target.harmonicDisclosure,
            home: true
        )
        coordinate(
            .transition,
            relationship: target.transitionExpectation,
            home: false,
            active: localBar >= max(0, length / 2)
        )

        if target.roleDensity == .change {
            let removable = [PerformanceRole.response, .percussion, .transition, .atmosphere]
                .first { result.contains($0) && $0 != focus }
            let replacement = [PerformanceRole.atmosphere, .response, .percussion, .transition]
                .first { !result.contains($0) }
            if let removable, let replacement {
                result.removeAll { $0 == removable }
                result.append(replacement)
            }
        }

        var required: Set<PerformanceRole> = [.foundation, focus]
        if kind != .majorBreak { required.insert(.motif) }
        let boundedDesiredCount = max(desiredCount, required.count)
        let preservingRaisedTransition =
            target.transitionExpectation == .raise &&
            localBar >= max(0, length / 2)
        let removalPriority: [PerformanceRole] = preservingRaisedTransition
            ? [.response, .atmosphere, .percussion, .transition, .motif]
            : [.transition, .response, .percussion, .atmosphere, .motif]
        while result.count > boundedDesiredCount,
              let removable = removalPriority.first(where: {
                  result.contains($0) && !required.contains($0)
              }) {
            result.removeAll { $0 == removable }
        }
        let additionPriority: [PerformanceRole] = [
            .motif, .percussion, .atmosphere, .response, .transition,
        ]
        while result.count < boundedDesiredCount,
              let addition = additionPriority.first(where: {
                  !result.contains($0)
              }) {
            result.append(addition)
        }
        return PerformanceRole.allCases.filter(result.contains).prefix(4).map { $0 }
    }

    private func coordinatedSupportingRoles(
        _ baseline: [PerformanceRole],
        kind: AutonomousPhraseKind,
        focus: PerformanceRole,
        target: LongHorizonEnergyTarget
    ) -> [PerformanceRole] {
        guard kind != .majorBreak else { return [.atmosphere] }
        guard !target.isNeutral else { return baseline }
        let proposed = roles(
            kind: kind,
            focus: focus,
            localBar: 0,
            length: 1,
            target: target
        )
        let desired = proposed.filter {
            $0 == .percussion || $0 == .response || $0 == .atmosphere
        }
        return NarrativeArticulation.supportingRoles(
            baseline.filter(desired.contains) + desired
        )
    }

    private func transformations(kind: AutonomousPhraseKind, localBar: Int,
                                 length: Int, seed: UInt64,
                                 relationship: LongHorizonEnergyRelationship = .hold)
        -> [MusicalTransformation] {
        let baseline: [MusicalTransformation]
        if localBar == 0 {
            baseline = switch kind {
            case .energyRelease: [.restore, .extend]
            case .identityReturn: [.restore]
            case .majorBreak: [.omit]
            case .contrast: [.rotate]
            case .lock: [.`repeat`]
            }
        } else if localBar == length - 1 {
            baseline = switch kind {
            case .majorBreak: [.fragment]
            case .energyRelease, .identityReturn: [.answer]
            default: [.extend]
            }
        } else {
            let roll = SceneDNA.derivedSeed(
                scene: seed,
                domain: 0x72A,
                index: localBar
            ) % 100
            if kind == .majorBreak {
                baseline = roll < 70 ? [.fragment] : [.omit]
            } else if roll < 62 {
                baseline = [.`repeat`]
            } else if roll < 76 {
                baseline = [.rotate]
            } else if roll < 90 {
                baseline = [.fragment]
            } else {
                baseline = [.answer]
            }
        }
        switch relationship {
        case .hold:
            return baseline
        case .lower:
            return localBar == 0 ? [.restore] : [.`repeat`]
        case .raise:
            return baseline.contains(where: { $0 != .`repeat` && $0 != .restore })
                ? baseline : [.rotate]
        case .change:
            return baseline.contains(.displace) ? [.rotate] : [.displace]
        case .home:
            return localBar == 0 ? [.restore] : [.`repeat`]
        }
    }

    private func tension(kind: AutonomousPhraseKind, progress: Double, prior: Double) -> Double {
        switch kind {
        case .lock: return min(0.72, max(0.32, prior * 0.72 + 0.18 + sin(progress * .pi * 2) * 0.06))
        case .contrast: return min(0.92, 0.48 + progress * 0.36)
        case .majorBreak: return max(0.26, 0.68 - progress * 0.34)
        case .energyRelease: return max(0.38, 0.92 - progress * 0.28)
        case .identityReturn: return 0.44 + progress * 0.12
        }
    }

    package static func ensemblePlan(dna: SceneDNA, bar: PerformanceBar,
                                     focus: PerformanceRole, release: Bool,
                                     kind: AutonomousPhraseKind,
                                     character: PerformanceCharacter = .hypnoticLock,
                                     foundationBehavior: FoundationBehavior? = nil,
                                     companion: FoundationCompanion,
                                     gear: PercussionGear,
                                     gesture: ArrangementGesture) -> EnsembleContext {
        let rotation = bar.transformations.contains(.rotate) ? 2 : 0
        let displacement = bar.transformations.contains(.displace) ? 1 : 0
        func shifted(_ step: Int) -> Int { (step + rotation + displacement) % 16 }
        let resolvedFoundationBehavior = foundationBehavior ?? FoundationBehavior(
            companion: companion
        )
        var kickSteps = characterKickSteps(
            dna: dna,
            bar: bar,
            character: character,
            kind: kind,
            gear: gear,
            gesture: gesture
        )
        if bar.signatureEvent == .displacedKickRecovery, let last = kickSteps.last {
            kickSteps.removeAll { $0 == last }
            kickSteps.append(min(15, last + 1))
            kickSteps.sort()
        }
        var proposals = kickSteps.map {
            EnsembleEventProposal(voice: .kick, requestedStep: $0, priority: 100,
                                  intensity: 1, essential: true)
        }
        if bar.roles.contains(.foundation), companion == .bass,
           !bar.transformations.contains(.omit) {
            let bassSteps = foundationBassSteps(
                dna: dna,
                kickSteps: kickSteps,
                behavior: resolvedFoundationBehavior
            )
            let bassIntensity: Double = switch resolvedFoundationBehavior {
            case .subPulse: 0.70
            case .monotone: 0.74
            case .point: 0.84
            case .pump: 0.78
            case .kickTail, .tunedPercussive, .absent: 0.76
            }
            proposals += bassSteps.map {
                let step = shifted($0)
                return EnsembleEventProposal(voice: .bass, requestedStep: step,
                                      alternateSteps: [step + 1, step + 3], priority: 90,
                                      intensity: bassIntensity, essential: true)
            }
        }
        if bar.roles.contains(.foundation), companion == .monoRumble {
            proposals += kickSteps.map {
                EnsembleEventProposal(voice: .rumble, requestedStep: $0,
                                      priority: 88, intensity: 0.46, essential: true)
            }
        }
        if bar.roles.contains(.foundation), companion == .tunedTom {
            let tomSteps = dna.characteristicSyncopations.isEmpty ? [10, 14] :
                Array(dna.characteristicSyncopations.prefix(2))
            proposals += tomSteps.map {
                EnsembleEventProposal(voice: .tunedTom, requestedStep: $0,
                                      alternateSteps: [$0 + 2], priority: 86,
                                      intensity: 0.58, essential: true)
            }
        }
        if bar.roles.contains(.percussion) {
            let hatCount: Int
            switch (gear, gesture) {
            case (_, .minimalize): hatCount = 1
            case (.anchor, _): hatCount = 2
            case (.lift, _): hatCount = 4
            case (.contrast, _): hatCount = 3
            case (.turnaround, _): hatCount = 2
            }
            proposals += dna.rhythm.hatSteps.prefix(hatCount).map {
                let step = shifted($0)
                return EnsembleEventProposal(voice: .percussion, requestedStep: step,
                                      alternateSteps: [step + 1], priority: 58, intensity: 0.48)
            }
            if gear == .lift && gesture != .minimalize {
                proposals += [4, 12].map {
                    EnsembleEventProposal(voice: .clap, requestedStep: $0,
                                          alternateSteps: [$0 + 1], priority: 62, intensity: 0.48)
                }
            }
            if gear == .contrast && gesture != .minimalize {
                proposals.append(EnsembleEventProposal(
                    voice: .openHat, requestedStep: bar.bar.isMultiple(of: 2) ? 6 : 14,
                    alternateSteps: [10], priority: 54, intensity: 0.42
                ))
            }
            if gear == .turnaround && gesture != .minimalize {
                proposals.append(EnsembleEventProposal(
                    voice: .metallic, requestedStep: 11,
                    alternateSteps: [13, 15], priority: 52, intensity: 0.38
                ))
            }
            proposals += GroovePulseResolver.proposals(
                absoluteBar: bar.bar,
                percussionActive: true,
                majorBreak: kind == .majorBreak,
                gesture: gesture
            )
        }
        if bar.roles.contains(.motif), !bar.transformations.contains(.omit) {
            let motifSteps = bar.transformations.contains(.fragment)
                ? Array(dna.motif.steps.prefix(1)) : dna.motif.steps
            proposals += motifSteps.map {
                let step = shifted($0)
                return EnsembleEventProposal(voice: .motif, requestedStep: step,
                                      alternateSteps: [step + 2, step + 5], priority: 72, intensity: 0.62)
            }
        }
        if bar.roles.contains(.response), let source = dna.motif.steps.first {
            proposals.append(EnsembleEventProposal(
                voice: .response,
                requestedStep: source + 6,
                alternateSteps: [source + 8, source + 10],
                priority: 64,
                intensity: 0.52
            ))
        }
        if bar.roles.contains(.atmosphere) {
            proposals.append(EnsembleEventProposal(voice: .atmosphere, requestedStep: 0,
                                                   alternateSteps: [8], priority: 32, intensity: 0.36))
        }
        if bar.roles.contains(.transition) {
            proposals.append(EnsembleEventProposal(voice: .transition, requestedStep: 15,
                                                   alternateSteps: [14, 12], priority: 48, intensity: 0.44))
        }
        let resolved = EnsembleArbiter.resolve(
            proposals: proposals,
            focusRole: focus,
            intentionalPileup: release
        )
        return GroovePulseResolver.resolvingAccentGrouping(
            in: resolved,
            absoluteBar: bar.bar,
            gesture: gesture,
            majorBreak: kind == .majorBreak
        )
    }

    private static func characterKickSteps(
        dna: SceneDNA,
        bar: PerformanceBar,
        character: PerformanceCharacter,
        kind: AutonomousPhraseKind,
        gear: PercussionGear,
        gesture: ArrangementGesture
    ) -> [Int] {
        switch character {
        case .hypnoticLock, .melodicGlow:
            return dna.rhythm.kickSteps
        case .acidPressure:
            return [0, 4, 8, 12]
        case .peakDrive:
            return gesture == .turnaround ? [0, 4, 8, 12, 15] : [0, 4, 8, 12]
        case .brokenSuspension:
            let shape = kind == .majorBreak ? 0.78 : 0.58
            let pattern = TechnoScene.beatShapePattern(
                beatShape: shape,
                seed: bar.eventSeed,
                bar: bar.bar
            ).kicks
            if kind == .majorBreak, gesture != .structuralMarker {
                let displaced = pattern.first { !$0.isMultiple(of: 4) } ?? 7
                let secondDisplaced = pattern.dropFirst().first {
                    !$0.isMultiple(of: 4) && $0 != displaced
                }
                if gear == .turnaround, let secondDisplaced {
                    return [0, displaced, secondDisplaced].sorted()
                }
                return [0, displaced].sorted()
            }
            return pattern
        case .ambientDrift:
            return gesture == .structuralMarker ? [0, 8] : [0]
        }
    }

    private static func foundationBassSteps(
        dna: SceneDNA,
        kickSteps: [Int],
        behavior: FoundationBehavior
    ) -> [Int] {
        let kickSet = Set(kickSteps)
        func available(_ values: [Int]) -> [Int] {
            var seen = Set<Int>()
            return values.map { (($0 % 16) + 16) % 16 }.filter {
                !kickSet.contains($0) && seen.insert($0).inserted
            }
        }
        let identity = available(dna.rhythm.bassSteps)
        switch behavior {
        case .subPulse:
            return Array((identity.isEmpty ? available([10, 14, 6]) : identity).prefix(1))
        case .monotone:
            return Array((identity.isEmpty ? available([6, 10, 14]) : identity).prefix(2))
        case .point:
            return Array(available(
                dna.characteristicSyncopations + dna.rhythm.bassSteps + [3, 10, 14]
            ).prefix(3))
        case .pump:
            return Array(available(kickSteps.map { $0 + 1 }).prefix(4))
        case .kickTail, .tunedPercussive, .absent:
            return []
        }
    }

    private func percussionGear(
        absoluteBar: Int,
        relationship: LongHorizonEnergyRelationship = .hold
    ) -> PercussionGear {
        let baseline: PercussionGear = switch (absoluteBar % 16) / 4 {
        case 0: .anchor
        case 1: .lift
        case 2: .contrast
        default: .turnaround
        }
        guard relationship != .hold else { return baseline }
        let tiers: [PercussionGear] = [.anchor, .turnaround, .contrast, .lift]
        let index = tiers.firstIndex(of: baseline) ?? 0
        switch relationship {
        case .hold:
            return baseline
        case .lower:
            return tiers[max(0, index - 1)]
        case .raise:
            return tiers[min(tiers.count - 1, index + 1)]
        case .change:
            if index == 0 { return tiers[1] }
            if index == tiers.count - 1 { return tiers[index - 1] }
            let quarter = (max(0, absoluteBar) % 16) / 4
            return quarter.isMultiple(of: 2) ? tiers[index + 1] : tiers[index - 1]
        case .home:
            return tiers[max(0, index - 1)]
        }
    }

    private func arrangementGesture(kind: AutonomousPhraseKind,
                                    absoluteBar: Int) -> ArrangementGesture {
        let endPosition = (absoluteBar + 1) % 16
        if endPosition == 0 {
            switch kind {
            case .majorBreak, .energyRelease, .identityReturn: return .structuralMarker
            case .lock, .contrast: return .turnaround
            }
        }
        switch endPosition {
        case 4: return .gearShift
        case 8: return .turnaround
        case 12: return .minimalize
        default: return .steady
        }
    }

    private func foundationResolution(
        character: PerformanceCharacter,
        kind: AutonomousPhraseKind,
        localBar: Int,
        length: Int,
        gesture: ArrangementGesture,
        relationship: LongHorizonEnergyRelationship = .hold
    ) -> (behavior: FoundationBehavior, companion: FoundationCompanion) {
        let behavior = PerformanceCharacterContract.foundationBehavior(
            for: character,
            gesture: gesture,
            localBar: localBar,
            phraseLength: length,
            energyRelationship: relationship
        )
        precondition(
            PerformanceCharacterContract.foundationIsCompatible(behavior, with: character),
            "Performance character emitted an incompatible foundation"
        )
        return (behavior, behavior.companion)
    }

    private func pulseEchoEnabled(scene: TechnoScene, bar: PerformanceBar,
                                  kind: AutonomousPhraseKind,
                                  companion: FoundationCompanion,
                                  gesture: ArrangementGesture,
                                  relationship: LongHorizonEnergyRelationship = .hold) -> Bool {
        let suitableMaterial = relationship == .raise || kind == .majorBreak ||
            scene.beatShape > 0.22 || scene.syncopation > 0.48
        guard companion != .monoRumble, suitableMaterial else { return false }
        guard gesture == .gearShift || gesture == .turnaround else { return false }
        let baseline = SceneDNA.derivedSeed(
            scene: bar.eventSeed,
            domain: 0x3E160EC40,
            index: bar.bar
        )
            .isMultiple(of: 3)
        switch relationship {
        case .hold: return baseline
        case .lower, .home: return false
        case .raise: return true
        case .change: return !baseline
        }
    }

    private func accentContour(dna: SceneDNA, absoluteBar: Int,
                               progress: Double, release: Bool) -> [Double] {
        (0..<16).map { step in
            let anchor = step.isMultiple(of: 4) ? 0.10 : 0
            let signature = dna.characteristicSyncopations.contains(step) ? 0.07 : 0
            let payoff = release && absoluteBar.isMultiple(of: 4) && step == 0 ? 0.16 : 0
            let variation = SceneDNA.derivedSeed(scene: rootSeed, domain: UInt64(absoluteBar + 1), index: step)
            let micro = (Double(variation % 1_001) / 1_000 - 0.5) * 0.035
            return min(1.24, max(0.76, 0.90 + anchor + signature + payoff + progress * 0.035 + micro))
        }
    }

    private func seed(state: AutonomousSessionState, domain: UInt64, index: Int) -> UInt64 {
        SceneDNA.derivedSeed(scene: state.rootSeed, domain: domain ^ UInt64(state.phraseIndex + 1), index: index)
    }

    private func thresholdSeed(state: AutonomousSessionState, domain: UInt64,
                               anchor: Int?) -> UInt64 {
        SceneDNA.derivedSeed(scene: state.rootSeed, domain: domain, index: max(0, anchor ?? 0))
    }
}
