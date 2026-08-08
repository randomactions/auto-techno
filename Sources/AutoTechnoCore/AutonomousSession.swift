import Foundation

package enum AutonomousPhraseKind: String, CaseIterable, Sendable {
    case lock
    case contrast
    case majorBreak
    case energyRelease
    case identityReturn
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

    package var role: PerformanceRole {
        switch self {
        case .kick, .bass, .rumble, .tunedTom: .foundation
        case .percussion, .clap, .openHat, .metallic: .percussion
        case .motif: .motif
        case .response: .response
        case .atmosphere: .atmosphere
        case .transition: .transition
        }
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

/// The single immutable score consumed by rendering for one bar. Keeping the
/// musical bar and its arbitrated events together prevents telemetry and PCM
/// from describing different performances.
package struct ResolvedPerformanceBar: Equatable, Sendable {
    package let performance: PerformanceBar
    package let ensemble: EnsembleContext
    package let arrangementGesture: ArrangementGesture
    package let percussionGear: PercussionGear
    package let foundationCompanion: FoundationCompanion
    package let pulseEchoEnabled: Bool
    package let interlockChapter: InterlockChapter

    package init(performance: PerformanceBar, ensemble: EnsembleContext,
                 arrangementGesture: ArrangementGesture, percussionGear: PercussionGear,
                 foundationCompanion: FoundationCompanion, pulseEchoEnabled: Bool,
                 interlockChapter: InterlockChapter) {
        self.performance = performance
        self.ensemble = ensemble
        self.arrangementGesture = arrangementGesture
        self.percussionGear = percussionGear
        self.foundationCompanion = foundationCompanion
        self.pulseEchoEnabled = pulseEchoEnabled && foundationCompanion != .monoRumble
        self.interlockChapter = interlockChapter
    }
}

package enum EnsembleArbiter {
    /// Resolves proposed events before rendering. Kick anchors are immutable,
    /// while other events may move to declared alternatives to preserve gaps.
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

    package init(recentBars: [MusicalMemoryBar] = [], currentPhrase: [MusicalMemoryBar] = [],
                previousPhrase: [MusicalMemoryBar] = [], dramaticArc: [MusicalMemoryBar] = [],
                sessionBars: [MusicalMemoryBar] = [], totalBars: Int = 0,
                lastContrastBar: Int? = nil, lastBreakBar: Int? = nil,
                lastReleaseBar: Int? = nil, lastIdentityReturnBar: Int? = nil,
                topologyRevision: Int = 0, openDebts: [SessionDramaticDebt] = [],
                interlockEvolution: InterlockEvolutionState = InterlockEvolutionState()) {
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
    }

    package var barsSinceContrast: Int { distance(since: lastContrastBar) }
    package var barsSinceBreak: Int { distance(since: lastBreakBar) }
    package var barsSinceRelease: Int { distance(since: lastReleaseBar) }

    package mutating func record(_ plan: AutonomousPhrasePlan) {
        previousPhrase = currentPhrase
        currentPhrase = plan.memoryBars
        recentBars = Array((recentBars + plan.memoryBars).suffix(4))
        sessionBars = Array((sessionBars + plan.memoryBars).suffix(256))
        dramaticArc = Array((dramaticArc + plan.memoryBars).suffix(128))
        totalBars = plan.startBar + plan.barCount
        interlockEvolution = plan.endingInterlockState

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
    package let overactivityPenalty: Double
    package let overdueDebtCount: Int
    package let score: Double
    package let valid: Bool

    package init(pulseClarity: Double, intentionalSpace: Double,
                responseClosure: Double, structuralTimeliness: Double,
                identityContinuity: Double, overactivityPenalty: Double,
                overdueDebtCount: Int) {
        let pulseValue = Self.clamp(pulseClarity)
        let spaceValue = Self.clamp(intentionalSpace)
        let responseClosureValue = Self.clamp(responseClosure)
        let timelinessValue = Self.clamp(structuralTimeliness)
        let identityValue = Self.clamp(identityContinuity)
        let overactivityValue = Self.clamp(overactivityPenalty)
        let overdueValue = max(0, overdueDebtCount)
        let computedScore = Self.clamp(
            pulseValue * 0.25 + spaceValue * 0.20 +
            responseClosureValue * 0.16 + timelinessValue * 0.18 +
            identityValue * 0.21 - overactivityValue * 0.24 -
            Double(overdueValue) * 0.20
        )
        self.pulseClarity = pulseValue
        self.intentionalSpace = spaceValue
        self.responseClosure = responseClosureValue
        self.structuralTimeliness = timelinessValue
        self.identityContinuity = identityValue
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
    package let alternate: Bool
    package let conservative: Bool
    package let interest: PhraseInterestReport
    package let endingInterlockState: InterlockEvolutionState

    package init(phraseIndex: Int, startBar: Int, barCount: Int,
                 kind: AutonomousPhraseKind, scene: TechnoScene, dna: SceneDNA,
                 resolvedBars: [ResolvedPerformanceBar], openedDebt: SessionDramaticDebt?,
                 paidDebtIDs: [Int], requestsTopologyMutation: Bool,
                 alternate: Bool, conservative: Bool, interest: PhraseInterestReport,
                 endingInterlockState: InterlockEvolutionState) {
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
        self.alternate = alternate
        self.conservative = conservative
        self.interest = interest
        self.endingInterlockState = endingInterlockState
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
                activity: Double(context.events.count) / 16,
                repetition: bar.transformations.contains(.`repeat`) ||
                    bar.transformations.contains(.restore) ? 1 : 0,
                density: Double(bar.roles.count) / Double(PerformanceRole.allCases.count)
            )
        }
    }
}

package struct AutonomousPhraseCandidates: Equatable, Sendable {
    package let primary: AutonomousPhrasePlan
    package let alternate: AutonomousPhrasePlan
    package let fallback: AutonomousPhrasePlan
}

package struct AutonomousSessionState: Equatable, Sendable {
    package let rootSeed: UInt64
    package let identitySeed: UInt64
    package let identityDNA: SceneDNA
    package var phraseIndex: Int
    package var intent: MusicalIntent
    package var memory: TemporalMusicalMemory

    package init(rootSeed: UInt64 = AutonomousSessionDirector.defaultSeed, phraseIndex: Int = 0,
                intent: MusicalIntent = MusicalIntent(),
                memory: TemporalMusicalMemory = TemporalMusicalMemory()) {
        let normalizedIntent = intent.preservingCorrelations()
        self.rootSeed = rootSeed
        identitySeed = rootSeed &+ 17
        identityDNA = SceneDNA(scene: TechnoScene(
            intent: normalizedIntent, seed: rootSeed &+ 17, bpm: AutonomousSessionDirector.bpm
        ))
        self.phraseIndex = max(0, phraseIndex)
        self.intent = normalizedIntent
        self.memory = memory
    }

    package mutating func advance(using plan: AutonomousPhrasePlan) {
        memory.record(plan)
        intent = plan.scene.musicalIntent.preservingCorrelations()
        phraseIndex = plan.phraseIndex + 1
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
            Double(ensemble.reduce(0) { $0 + $1.events.count }) / Double(ensemble.count)
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
        let phraseEnd = (bars.last?.bar ?? memory.totalBars) + 1
        let overdue = memory.openDebts.filter { $0.dueByBar < phraseEnd && kind != .energyRelease }.count
        return PhraseInterestReport(
            pulseClarity: pulseClarity,
            intentionalSpace: intentionalSpace,
            responseClosure: responseClosure,
            structuralTimeliness: structuralTimeliness,
            identityContinuity: identityPreserved ? 1 : 0,
            overactivityPenalty: overactivityPenalty,
            overdueDebtCount: overdue
        )
    }
}

/// Pure, deterministic session policy. It produces complete immutable phrase
/// candidates; rendering and candidate audio comparison live in AutoTechnoDSP.
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

    package func candidates(from state: AutonomousSessionState) -> AutonomousPhraseCandidates {
        let kind = nextKind(state: state)
        return AutonomousPhraseCandidates(
            primary: makePlan(state: state, kind: kind, alternate: false, conservative: false),
            alternate: makePlan(state: state, kind: kind, alternate: true, conservative: false),
            fallback: makePlan(state: state, kind: .identityReturn, alternate: false, conservative: true)
        )
    }

    private func nextKind(state: AutonomousSessionState) -> AutonomousPhraseKind {
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

    private func makePlan(state: AutonomousSessionState, kind: AutonomousPhraseKind,
                          alternate: Bool, conservative: Bool) -> AutonomousPhrasePlan {
        let start = state.memory.totalBars
        let rawLength = 4 + Int(seed(state: state, domain: conservative ? 0xFA11BAC : 0xF4A5E,
                                     index: alternate ? 1 : 0) % 13)
        let baseLength = conservative ? 8 : rawLength
        let structuralKind = kind == .majorBreak || kind == .energyRelease || kind == .identityReturn
        let barsToMacroBoundary = 16 - (start % 16)
        // Structural phrases always contain the next global sixteen-bar
        // resolution point while retaining the adaptive four-to-sixteen-bar
        // phrase vocabulary.
        let length = structuralKind ? max(baseLength, barsToMacroBoundary) : baseLength
        let mutationAmount: Double
        switch kind {
        case .lock: mutationAmount = alternate ? 0.10 : 0.035
        case .contrast: mutationAmount = alternate ? 0.20 : 0.13
        case .majorBreak: mutationAmount = alternate ? 0.16 : 0.10
        case .energyRelease: mutationAmount = alternate ? 0.11 : 0.07
        case .identityReturn: mutationAmount = conservative ? 0 : 0.045
        }
        let phraseSeed = seed(state: state, domain: 0x51A7E, index: alternate ? 1 : 0)
        let intent = MusicalIntent.mutated(state.intent, seed: phraseSeed, amount: mutationAmount)
            .preservingCorrelations()
        let scene = TechnoScene(intent: intent, seed: state.identitySeed, bpm: Self.bpm)
        // Rhythm, motif, tonal centre and timbral family are session identity.
        // Phrase intentions may reinterpret them but never silently replace
        // them with an independently generated scene identity.
        let dna = state.identityDNA
        let section = section(for: kind)
        let focusRole = focus(kind: kind, alternate: alternate, seed: phraseSeed)
        var resolvedBars: [ResolvedPerformanceBar] = []
        resolvedBars.reserveCapacity(length)
        var interlockState = state.memory.interlockEvolution

        for localBar in 0..<length {
            let progress = length == 1 ? 1 : Double(localBar) / Double(length - 1)
            let tension = tension(kind: kind, progress: progress, prior: state.memory.currentPhrase.last?.tension ?? 0.42)
            let transformations = transformations(kind: kind, localBar: localBar, length: length,
                                                   alternate: alternate, seed: phraseSeed)
            let roles = roles(kind: kind, focus: focusRole, localBar: localBar, length: length)
            let absoluteBar = start + localBar
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
                roles: roles,
                transformations: transformations,
                signatureEvent: signature,
                eventSeed: SceneDNA.derivedSeed(scene: phraseSeed, domain: 0xBA2, index: localBar),
                accentContour: contour
            )
            let gesture = arrangementGesture(kind: kind, absoluteBar: absoluteBar)
            let gear = percussionGear(absoluteBar: absoluteBar)
            let companion = foundationCompanion(
                dna: dna, kind: kind, alternate: alternate,
                localBar: localBar, length: length, gesture: gesture
            )
            let ensemble = ensemblePlan(
                dna: dna, bar: bar, focus: focusRole,
                release: kind == .energyRelease, companion: companion,
                gear: gear, gesture: gesture
            )
            let echoEnabled = pulseEchoEnabled(
                scene: scene, bar: bar, kind: kind,
                companion: companion, gesture: gesture
            )
            resolvedBars.append(ResolvedPerformanceBar(
                performance: bar,
                ensemble: ensemble,
                arrangementGesture: gesture,
                percussionGear: gear,
                foundationCompanion: companion,
                pulseEchoEnabled: echoEnabled,
                interlockChapter: interlockState.currentChapter
            ))
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
        let interest = PhraseInterestEvaluator.evaluate(
            resolvedBars: resolvedBars,
            kind: kind,
            memory: state.memory,
            identityPreserved: scene.seed == state.identitySeed
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
                (kind == .contrast || kind == .majorBreak) && !conservative,
            alternate: alternate,
            conservative: conservative,
            interest: interest,
            endingInterlockState: interlockState
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

    private func focus(kind: AutonomousPhraseKind, alternate: Bool, seed: UInt64) -> PerformanceRole {
        switch kind {
        case .majorBreak: return .atmosphere
        case .energyRelease: return .foundation
        case .identityReturn: return .motif
        case .contrast: return alternate ? .response : .percussion
        case .lock:
            let palette: [PerformanceRole] = [.foundation, .percussion, .motif, .atmosphere]
            return palette[Int(seed % UInt64(palette.count))]
        }
    }

    private func roles(kind: AutonomousPhraseKind, focus: PerformanceRole,
                       localBar: Int, length: Int) -> [PerformanceRole] {
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
        return result
    }

    private func transformations(kind: AutonomousPhraseKind, localBar: Int, length: Int,
                                 alternate: Bool, seed: UInt64) -> [MusicalTransformation] {
        if localBar == 0 {
            switch kind {
            case .energyRelease: return [.restore, .extend]
            case .identityReturn: return [.restore]
            case .majorBreak: return [.omit]
            case .contrast: return alternate ? [.displace] : [.rotate]
            case .lock: return [.`repeat`]
            }
        }
        if localBar == length - 1 {
            switch kind {
            case .majorBreak: return [.fragment]
            case .energyRelease, .identityReturn: return [.answer]
            default: return [.extend]
            }
        }
        let roll = SceneDNA.derivedSeed(scene: seed, domain: 0x72A, index: localBar) % 100
        if kind == .majorBreak { return roll < 70 ? [.fragment] : [.omit] }
        if roll < 62 { return [.`repeat`] }
        if roll < 76 { return alternate ? [.displace] : [.rotate] }
        if roll < 90 { return [.fragment] }
        return [.answer]
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

    private func ensemblePlan(dna: SceneDNA, bar: PerformanceBar,
                              focus: PerformanceRole, release: Bool,
                              companion: FoundationCompanion,
                              gear: PercussionGear,
                              gesture: ArrangementGesture) -> EnsembleContext {
        let rotation = bar.transformations.contains(.rotate) ? 2 : 0
        let displacement = bar.transformations.contains(.displace) ? 1 : 0
        func shifted(_ step: Int) -> Int { (step + rotation + displacement) % 16 }
        var kickSteps = dna.rhythm.kickSteps
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
            proposals += dna.rhythm.bassSteps.map {
                let step = shifted($0)
                return EnsembleEventProposal(voice: .bass, requestedStep: step,
                                      alternateSteps: [step + 1, step + 3], priority: 90,
                                      intensity: 0.76, essential: true)
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
        return EnsembleArbiter.resolve(proposals: proposals, focusRole: focus, intentionalPileup: release)
    }

    private func percussionGear(absoluteBar: Int) -> PercussionGear {
        switch (absoluteBar % 16) / 4 {
        case 0: .anchor
        case 1: .lift
        case 2: .contrast
        default: .turnaround
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

    private func foundationCompanion(dna: SceneDNA, kind: AutonomousPhraseKind,
                                     alternate: Bool, localBar: Int, length: Int,
                                     gesture: ArrangementGesture) -> FoundationCompanion {
        switch kind {
        case .majorBreak:
            return gesture == .structuralMarker ? .tunedTom : .empty
        case .contrast where alternate && localBar >= length / 2:
            switch dna.foundationCompanion {
            case .bass: return .monoRumble
            case .monoRumble: return .tunedTom
            case .tunedTom, .empty: return .bass
            }
        case .lock, .contrast, .energyRelease, .identityReturn:
            return dna.foundationCompanion
        }
    }

    private func pulseEchoEnabled(scene: TechnoScene, bar: PerformanceBar,
                                  kind: AutonomousPhraseKind,
                                  companion: FoundationCompanion,
                                  gesture: ArrangementGesture) -> Bool {
        let suitableMaterial = kind == .majorBreak || scene.beatShape > 0.22 ||
            scene.syncopation > 0.48
        guard companion != .monoRumble, suitableMaterial else { return false }
        guard gesture == .gearShift || gesture == .turnaround else { return false }
        return SceneDNA.derivedSeed(scene: bar.eventSeed, domain: 0x3E160EC40, index: bar.bar)
            .isMultiple(of: 3)
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
