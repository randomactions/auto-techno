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
    case percussion
    case motif
    case response
    case atmosphere
    case transition

    package var role: PerformanceRole {
        switch self {
        case .kick, .bass: .foundation
        case .percussion: .percussion
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

    package init(recentBars: [MusicalMemoryBar] = [], currentPhrase: [MusicalMemoryBar] = [],
                previousPhrase: [MusicalMemoryBar] = [], dramaticArc: [MusicalMemoryBar] = [],
                sessionBars: [MusicalMemoryBar] = [], totalBars: Int = 0,
                lastContrastBar: Int? = nil, lastBreakBar: Int? = nil,
                lastReleaseBar: Int? = nil, lastIdentityReturnBar: Int? = nil,
                topologyRevision: Int = 0, openDebts: [SessionDramaticDebt] = []) {
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
    package let repetition: Double
    package let roleDiversity: Double
    package let tensionMovement: Double
    package let responseClosure: Double
    package let structuralTimeliness: Double
    package let identityContinuity: Double
    package let overdueDebtCount: Int
    package let score: Double
    package let valid: Bool

    package init(repetition: Double, roleDiversity: Double, tensionMovement: Double,
                responseClosure: Double, structuralTimeliness: Double,
                identityContinuity: Double, overdueDebtCount: Int) {
        let repetitionValue = Self.clamp(repetition)
        let roleDiversityValue = Self.clamp(roleDiversity)
        let tensionMovementValue = Self.clamp(tensionMovement)
        let responseClosureValue = Self.clamp(responseClosure)
        let timelinessValue = Self.clamp(structuralTimeliness)
        let identityValue = Self.clamp(identityContinuity)
        let overdueValue = max(0, overdueDebtCount)
        let computedScore = Self.clamp(
            repetitionValue * 0.18 + roleDiversityValue * 0.18 +
            tensionMovementValue * 0.16 + responseClosureValue * 0.14 +
            timelinessValue * 0.18 + identityValue * 0.16 -
            Double(overdueValue) * 0.18
        )
        self.repetition = repetitionValue
        self.roleDiversity = roleDiversityValue
        self.tensionMovement = tensionMovementValue
        self.responseClosure = responseClosureValue
        self.structuralTimeliness = timelinessValue
        self.identityContinuity = identityValue
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
    package let bars: [PerformanceBar]
    package let ensemble: [EnsembleContext]
    package let openedDebt: SessionDramaticDebt?
    package let paidDebtIDs: [Int]
    package let requestsTopologyMutation: Bool
    package let alternate: Bool
    package let conservative: Bool
    package let interest: PhraseInterestReport

    package var memoryBars: [MusicalMemoryBar] {
        zip(bars, ensemble).map { bar, context in
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
    package static func evaluate(bars: [PerformanceBar], ensemble: [EnsembleContext],
                                kind: AutonomousPhraseKind, memory: TemporalMusicalMemory,
                                identityPreserved: Bool) -> PhraseInterestReport {
        let priorSignatures = memory.recentBars.map(\.eventSignature)
        let newSignatures = ensemble.map(ensembleEventSignature)
        let repeated = zip(priorSignatures.suffix(newSignatures.count), newSignatures)
            .filter { $0.0 == $0.1 }.count
        let repetition = newSignatures.isEmpty ? 0 : 1 - Double(repeated) / Double(newSignatures.count)
        let distinctRoles = Set(bars.flatMap(\.roles).map(\.rawValue)).count
        let roleDiversity = min(1, Double(distinctRoles) / 5)
        let tensionRange = (bars.map(\.tension).max() ?? 0) - (bars.map(\.tension).min() ?? 0)
        let tensionMovement = min(1, tensionRange * 4 + (kind == .lock ? 0.20 : 0.48))
        let hasMotif = bars.contains { $0.roles.contains(.motif) }
        let hasResponse = bars.contains { $0.roles.contains(.response) }
        let responseClosure = !hasMotif || hasResponse || kind == .majorBreak ? 1 : 0.35
        let timely = kind == .energyRelease || kind == .majorBreak || kind == .contrast ||
            (memory.barsSinceContrast < 24 && memory.barsSinceBreak < 96 && memory.barsSinceRelease < 128)
        let structuralTimeliness = timely ? 1 : 0.20
        let phraseEnd = (bars.last?.bar ?? memory.totalBars) + 1
        let overdue = memory.openDebts.filter { $0.dueByBar < phraseEnd && kind != .energyRelease }.count
        return PhraseInterestReport(
            repetition: repetition,
            roleDiversity: roleDiversity,
            tensionMovement: tensionMovement,
            responseClosure: responseClosure,
            structuralTimeliness: structuralTimeliness,
            identityContinuity: identityPreserved ? 1 : 0,
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
        let length = conservative ? 8 : rawLength
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
        var performanceBars: [PerformanceBar] = []
        var ensembleBars: [EnsembleContext] = []
        performanceBars.reserveCapacity(length)
        ensembleBars.reserveCapacity(length)

        for localBar in 0..<length {
            let progress = length == 1 ? 1 : Double(localBar) / Double(length - 1)
            let tension = tension(kind: kind, progress: progress, prior: state.memory.currentPhrase.last?.tension ?? 0.42)
            let transformations = transformations(kind: kind, localBar: localBar, length: length,
                                                   alternate: alternate, seed: phraseSeed)
            let roles = roles(kind: kind, focus: focusRole, localBar: localBar, length: length)
            let signature: SignatureEvent? = kind == .energyRelease && localBar == 0
                ? .displacedKickRecovery
                : (kind == .identityReturn && localBar == length - 1 ? .alteredMotifAnswer : nil)
            let absoluteBar = start + localBar
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
            performanceBars.append(bar)
            ensembleBars.append(ensemblePlan(dna: dna, bar: bar, focus: focusRole,
                                             release: kind == .energyRelease))
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
            bars: performanceBars,
            ensemble: ensembleBars,
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
            bars: performanceBars,
            ensemble: ensembleBars,
            openedDebt: openedDebt,
            paidDebtIDs: paidDebtIDs,
            requestsTopologyMutation: state.phraseIndex > 0 && kind != .energyRelease && !conservative,
            alternate: alternate,
            conservative: conservative,
            interest: interest
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
                              focus: PerformanceRole, release: Bool) -> EnsembleContext {
        var proposals = dna.rhythm.kickSteps.map {
            EnsembleEventProposal(voice: .kick, requestedStep: $0, priority: 100,
                                  intensity: 1, essential: true)
        }
        if bar.roles.contains(.foundation) {
            proposals += dna.rhythm.bassSteps.map {
                EnsembleEventProposal(voice: .bass, requestedStep: $0,
                                      alternateSteps: [$0 + 1, $0 + 3], priority: 90,
                                      intensity: 0.76, essential: true)
            }
        }
        if bar.roles.contains(.percussion) {
            proposals += dna.rhythm.hatSteps.prefix(5).map {
                EnsembleEventProposal(voice: .percussion, requestedStep: $0,
                                      alternateSteps: [$0 + 1], priority: 58, intensity: 0.48)
            }
        }
        if bar.roles.contains(.motif) {
            proposals += dna.motif.steps.map {
                EnsembleEventProposal(voice: .motif, requestedStep: $0,
                                      alternateSteps: [$0 + 2, $0 + 5], priority: 72, intensity: 0.62)
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
