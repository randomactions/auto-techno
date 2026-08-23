import Foundation

/// Version and fixed-capacity contract for the Phase 1 semantic trajectory.
/// The schema is descriptive only: no threshold here selects or rejects music.
package enum LongHorizonSemanticTrajectorySchema {
    package static let schemaVersion = 1
    package static let schemaIdentifier = "autotechno-long-horizon-semantic.v1"
    package static let maximumPhraseBarCount = 16
    package static let periodicityLagCapacity = 64
    package static let recentSemanticBarCapacity = 64
    package static let eventSignatureRecurrenceCapacity = 64
    package static let identityLandmarkCapacity = 16
    package static let dramaticDebtCapacity = 16
    package static let highTensionObservationFloor = 0.8
    package static let recoveryTensionObservationCeiling = 0.4
}

package enum LongHorizonTrajectoryAvailability: String, Codable, Sendable {
    case available
    case unavailable
}

package enum LongHorizonTrajectoryQualificationStatus: String, Codable, Sendable {
    case unavailable
}

package enum LongHorizonTrajectoryUnavailableReason: String, Codable, Sendable {
    case noObservations = "no-observations"
    case rootSeedMismatch = "root-seed-mismatch"
    case phraseIndexDiscontinuity = "phrase-index-discontinuity"
    case barDiscontinuity = "bar-discontinuity"
    case emptyPhrase = "empty-phrase"
    case phraseTooLong = "phrase-too-long"
    case inconsistentCanonicalPlan = "inconsistent-canonical-plan"
    case invalidSemanticScalar = "invalid-semantic-scalar"
    case invalidDebt = "invalid-debt"
    case unknownPaidDebt = "unknown-paid-debt"
    case dramaticDebtCapacityExceeded = "dramatic-debt-capacity-exceeded"
}

package enum LongHorizonTrajectoryObservationResult: Equatable, Sendable {
    case accepted
    case unavailable(LongHorizonTrajectoryUnavailableReason)
}

/// Fixed semantic capabilities already present in the canonical score. These
/// labels describe use and recurrence; they are not another effects graph.
package enum LongHorizonSemanticCapability: String, CaseIterable, Codable,
        Hashable, Sendable {
    case groovePulse = "groove-pulse"
    case closedHatCompanion = "closed-hat-companion"
    case upperPercussionClearance = "upper-percussion-clearance"
    case modalPercussion = "modal-percussion"
    case spatialDistance = "spatial-distance"
    case pulseEcho = "pulse-echo"
    case dottedFoundationRhythm = "dotted-foundation-rhythm"
    case kickWithholding = "kick-withholding"
    case kickRecovery = "kick-recovery"
    case climaxHang = "climax-hang"
    case gatedPercussionEcho = "gated-percussion-echo"
    case anticipationSwell = "anticipation-swell"
    case audioSlice = "audio-slice"
    case arpeggiator
    case padHarmony = "pad-harmony"
    case harmonicDisclosure = "harmonic-disclosure"
    case padRhythmicModulation = "pad-rhythmic-modulation"
}

package struct LongHorizonSemanticDebtObservation: Equatable, Sendable {
    package let id: Int
    package let openedAtBar: Int
    package let dueByBar: Int
    package let source: AutonomousPhraseKind

    package init(
        id: Int,
        openedAtBar: Int,
        dueByBar: Int,
        source: AutonomousPhraseKind
    ) {
        self.id = id
        self.openedAtBar = openedAtBar
        self.dueByBar = dueByBar
        self.source = source
    }
}

/// One typed score observation. It contains no PCM, DSP type, or quality
/// decision and is bounded by the canonical phrase envelope.
package struct LongHorizonSemanticBarObservation: Equatable, Sendable {
    package let absoluteBar: Int
    package let section: SectionKind
    package let tension: Double
    package let roles: [PerformanceRole]
    package let transformations: [MusicalTransformation]
    package let eventSignature: UInt64
    package let activity: Double
    package let repetition: Double
    package let density: Double
    package let focusRole: PerformanceRole
    package let foundationBehavior: FoundationBehavior
    package let arrangementGesture: ArrangementGesture
    package let percussionGear: PercussionGear
    package let kickSyntaxRole: KickSyntaxRole
    package let interlockChapter: InterlockChapter
    package let signatureEvent: SignatureEvent?
    package let harmonicFunction: PadHarmonicFunction?
    package let capabilities: [LongHorizonSemanticCapability]

    package init(
        absoluteBar: Int,
        section: SectionKind,
        tension: Double,
        roles: [PerformanceRole],
        transformations: [MusicalTransformation],
        eventSignature: UInt64,
        activity: Double,
        repetition: Double,
        density: Double,
        focusRole: PerformanceRole,
        foundationBehavior: FoundationBehavior,
        arrangementGesture: ArrangementGesture,
        percussionGear: PercussionGear,
        kickSyntaxRole: KickSyntaxRole,
        interlockChapter: InterlockChapter,
        signatureEvent: SignatureEvent?,
        harmonicFunction: PadHarmonicFunction?,
        capabilities: [LongHorizonSemanticCapability]
    ) {
        self.absoluteBar = absoluteBar
        self.section = section
        self.tension = tension
        self.roles = PerformanceRole.allCases.filter(roles.contains)
        self.transformations = MusicalTransformation.allCases.filter(
            transformations.contains
        )
        self.eventSignature = eventSignature
        self.activity = activity
        self.repetition = repetition
        self.density = density
        self.focusRole = focusRole
        self.foundationBehavior = foundationBehavior
        self.arrangementGesture = arrangementGesture
        self.percussionGear = percussionGear
        self.kickSyntaxRole = kickSyntaxRole
        self.interlockChapter = interlockChapter
        self.signatureEvent = signatureEvent
        self.harmonicFunction = harmonicFunction
        self.capabilities = LongHorizonSemanticCapability.allCases.filter(
            capabilities.contains
        )
    }
}

package struct LongHorizonSemanticPhraseObservation: Equatable, Sendable {
    package let rootSeed: UInt64
    package let phraseIndex: Int
    package let startBar: Int
    package let kind: AutonomousPhraseKind
    package let character: PerformanceCharacter
    package let bars: [LongHorizonSemanticBarObservation]
    package let openedDebt: LongHorizonSemanticDebtObservation?
    package let paidDebtIDs: [Int]

    package init(
        rootSeed: UInt64,
        phraseIndex: Int,
        startBar: Int,
        kind: AutonomousPhraseKind,
        character: PerformanceCharacter,
        bars: [LongHorizonSemanticBarObservation],
        openedDebt: LongHorizonSemanticDebtObservation?,
        paidDebtIDs: [Int]
    ) {
        self.rootSeed = rootSeed
        self.phraseIndex = phraseIndex
        self.startBar = startBar
        self.kind = kind
        self.character = character
        self.bars = bars
        self.openedDebt = openedDebt
        self.paidDebtIDs = paidDebtIDs
    }
}

package struct LongHorizonNamedCount: Codable, Equatable, Sendable {
    package let name: String
    package let count: Int
}

package struct LongHorizonNamedRecurrenceEvidence: Codable, Equatable, Sendable {
    package let name: String
    package let activeBarCount: Int
    package let activationCount: Int
    package let currentRunBars: Int
    package let maximumRunBars: Int
    package let minimumInactiveGapBars: Int?
    package let maximumInactiveGapBars: Int?
    package let meanInactiveGapBars: Double?
    package let firstActiveBar: Int?
    package let lastActiveBar: Int?
}

package struct LongHorizonScalarTrajectoryEvidence: Codable, Equatable, Sendable {
    package let observationCount: Int
    package let first: Double?
    package let last: Double?
    package let minimum: Double?
    package let maximum: Double?
    package let mean: Double?
    package let maximumAbsoluteStep: Double
    package let directionChangeCount: Int
}

package struct LongHorizonTensionDwellEvidence: Codable, Equatable, Sendable {
    package let highObservationFloor: Double
    package let recoveryObservationCeiling: Double
    package let highBarCount: Int
    package let recoveryBarCount: Int
    package let currentHighDwellBars: Int
    package let maximumHighDwellBars: Int
    package let currentRecoveryDwellBars: Int
    package let maximumRecoveryDwellBars: Int
}

package struct LongHorizonPeriodicityLagEvidence: Codable, Equatable, Sendable {
    package let lagBars: Int
    package let comparisonCount: Int
    package let semanticMatchCount: Int
    package let eventSignatureMatchCount: Int
    package let tensionBandMatchCount: Int
    package let semanticMatchRate: Double?
    package let eventSignatureMatchRate: Double?
    package let tensionBandMatchRate: Double?
}

package struct LongHorizonIdentityRecallEvidence: Codable, Equatable, Sendable {
    package let landmarkCapacity: Int
    package let landmarkCount: Int
    package let identityReturnBarCount: Int
    package let matchedHomeSignatureBarCount: Int
    package let unmatchedHomeSignatureBarCount: Int
    package let minimumMatchedAbsenceBars: Int?
    package let maximumMatchedAbsenceBars: Int?
    package let meanMatchedAbsenceBars: Double?
}

package struct LongHorizonEventSignatureRecurrenceEvidence: Codable, Equatable,
        Sendable {
    package let capacity: Int
    package let trackedSignatureCount: Int
    package let observationCount: Int
    package let repeatObservationCount: Int
    package let recurrenceGapCount: Int
    package let minimumInactiveGapBars: Int?
    package let maximumInactiveGapBars: Int?
    package let meanInactiveGapBars: Double?
    package let maximumRunBars: Int
    package let evictionCount: Int
}

package struct LongHorizonDramaticDebtEvidence: Codable, Equatable, Sendable {
    package let capacity: Int
    package let initialOutstandingCount: Int
    package let openedCount: Int
    package let paidCount: Int
    package let zeroAgePaidCount: Int
    package let overduePaidCount: Int
    package let maximumOpenCount: Int
    package let maximumObservedAgeBars: Int
    package let outstandingCount: Int
    package let overdueOutstandingCount: Int
    package let oldestOutstandingAgeBars: Int
    package let sourceOpenedCounts: [LongHorizonNamedCount]
    package let sourcePaidCounts: [LongHorizonNamedCount]
}

package struct LongHorizonTrajectoryStorageEvidence: Codable, Equatable, Sendable {
    package let periodicityLagCapacity: Int
    package let periodicityLagCount: Int
    package let recentSemanticBarCapacity: Int
    package let recentSemanticBarCount: Int
    package let eventSignatureRecurrenceCapacity: Int
    package let eventSignatureRecurrenceCount: Int
    package let identityLandmarkCapacity: Int
    package let identityLandmarkCount: Int
    package let dramaticDebtCapacity: Int
    package let dramaticDebtCount: Int
    package let namedRecurrenceSlotCount: Int
}

/// Bounded, interpretable Phase 1 output. It has no aggregate engagement score
/// and cannot carry a pass, reject, adjustment, or future-selection request.
package struct LongHorizonSemanticTrajectoryReport: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let schemaIdentifier: String
    package let engineVersion: String
    package let availability: LongHorizonTrajectoryAvailability
    package let unavailableReason: LongHorizonTrajectoryUnavailableReason?
    package let qualificationStatus: LongHorizonTrajectoryQualificationStatus
    package let qualificationReason: String
    package let rootSeed: UInt64
    package let startingPhraseIndex: Int
    package let startingBar: Int
    package let nextExpectedPhraseIndex: Int
    package let nextExpectedBar: Int
    package let observedPhraseCount: Int
    package let observedBarCount: Int
    package let trajectoryFingerprint: String
    package let phraseKindPhraseCounts: [LongHorizonNamedCount]
    package let phraseKindRecurrence: [LongHorizonNamedRecurrenceEvidence]
    package let performanceCharacterPhraseCounts: [LongHorizonNamedCount]
    package let performanceCharacterRecurrence: [LongHorizonNamedRecurrenceEvidence]
    package let sectionBarCounts: [LongHorizonNamedCount]
    package let roleBarCounts: [LongHorizonNamedCount]
    package let focusRoleBarCounts: [LongHorizonNamedCount]
    package let foundationBehaviorBarCounts: [LongHorizonNamedCount]
    package let arrangementGestureBarCounts: [LongHorizonNamedCount]
    package let arrangementGestureRecurrence: [LongHorizonNamedRecurrenceEvidence]
    package let percussionGearBarCounts: [LongHorizonNamedCount]
    package let kickSyntaxRoleBarCounts: [LongHorizonNamedCount]
    package let interlockChapterBarCounts: [LongHorizonNamedCount]
    package let transformationBarCounts: [LongHorizonNamedCount]
    package let transformationRecurrence: [LongHorizonNamedRecurrenceEvidence]
    package let signatureEventBarCounts: [LongHorizonNamedCount]
    package let signatureEventRecurrence: [LongHorizonNamedRecurrenceEvidence]
    package let harmonicFunctionBarCounts: [LongHorizonNamedCount]
    package let harmonicFunctionRecurrence: [LongHorizonNamedRecurrenceEvidence]
    package let capabilityRecurrence: [LongHorizonNamedRecurrenceEvidence]
    package let eventSignatureRecurrence:
        LongHorizonEventSignatureRecurrenceEvidence
    package let tension: LongHorizonScalarTrajectoryEvidence
    package let activity: LongHorizonScalarTrajectoryEvidence
    package let repetition: LongHorizonScalarTrajectoryEvidence
    package let density: LongHorizonScalarTrajectoryEvidence
    package let tensionDwell: LongHorizonTensionDwellEvidence
    package let periodicity: [LongHorizonPeriodicityLagEvidence]
    package let dominantSemanticPeriodicity: LongHorizonPeriodicityLagEvidence?
    package let identityRecall: LongHorizonIdentityRecallEvidence
    package let dramaticDebt: LongHorizonDramaticDebtEvidence
    package let storage: LongHorizonTrajectoryStorageEvidence
}

/// Streaming semantic observation owned by Core. All collections have fixed
/// domain or explicit capacity; report creation cannot influence planning.
package struct LongHorizonSemanticTrajectoryAccumulator: Sendable {
    private let rootSeed: UInt64
    private let startingPhraseIndex: Int
    private let startingBar: Int
    private var nextExpectedPhraseIndex: Int
    private var nextExpectedBar: Int
    private var terminalReason: LongHorizonTrajectoryUnavailableReason?
    private var observedPhraseCount = 0
    private var observedBarCount = 0
    private var trajectoryHasher = LongHorizonSemanticHasher()

    private var phraseKindPhraseCounts = LongHorizonNamedCounterState(
        names: AutonomousPhraseKind.allCases.map(\.rawValue)
    )
    private var performanceCharacterPhraseCounts = LongHorizonNamedCounterState(
        names: PerformanceCharacter.allCases.map(\.rawValue)
    )
    private var sectionBarCounts = LongHorizonNamedCounterState(
        names: SectionKind.allCases.map(\.rawValue)
    )
    private var roleBarCounts = LongHorizonNamedCounterState(
        names: PerformanceRole.allCases.map(\.rawValue)
    )
    private var focusRoleBarCounts = LongHorizonNamedCounterState(
        names: PerformanceRole.allCases.map(\.rawValue)
    )
    private var foundationBehaviorBarCounts = LongHorizonNamedCounterState(
        names: FoundationBehavior.allCases.map(\.rawValue)
    )
    private var arrangementGestureBarCounts = LongHorizonNamedCounterState(
        names: ArrangementGesture.allCases.map(\.rawValue)
    )
    private var percussionGearBarCounts = LongHorizonNamedCounterState(
        names: PercussionGear.allCases.map(\.rawValue)
    )
    private var kickSyntaxRoleBarCounts = LongHorizonNamedCounterState(
        names: KickSyntaxRole.allCases.map(\.rawValue)
    )
    private var interlockChapterBarCounts = LongHorizonNamedCounterState(
        names: InterlockChapter.allCases.map(\.rawValue)
    )
    private var transformationBarCounts = LongHorizonNamedCounterState(
        names: MusicalTransformation.allCases.map(\.rawValue)
    )
    private var signatureEventBarCounts = LongHorizonNamedCounterState(
        names: SignatureEvent.allCases.map(\.rawValue)
    )
    private var harmonicFunctionBarCounts = LongHorizonNamedCounterState(
        names: PadHarmonicFunction.allCases.map(\.rawValue)
    )

    private var phraseKindRecurrence = LongHorizonNamedRecurrenceCollection(
        names: AutonomousPhraseKind.allCases.map(\.rawValue)
    )
    private var performanceCharacterRecurrence = LongHorizonNamedRecurrenceCollection(
        names: PerformanceCharacter.allCases.map(\.rawValue)
    )
    private var arrangementGestureRecurrence = LongHorizonNamedRecurrenceCollection(
        names: ArrangementGesture.allCases.map(\.rawValue)
    )
    private var transformationRecurrence = LongHorizonNamedRecurrenceCollection(
        names: MusicalTransformation.allCases.map(\.rawValue)
    )
    private var signatureEventRecurrence = LongHorizonNamedRecurrenceCollection(
        names: SignatureEvent.allCases.map(\.rawValue)
    )
    private var harmonicFunctionRecurrence = LongHorizonNamedRecurrenceCollection(
        names: PadHarmonicFunction.allCases.map(\.rawValue)
    )
    private var capabilityRecurrence = LongHorizonNamedRecurrenceCollection(
        names: LongHorizonSemanticCapability.allCases.map(\.rawValue)
    )
    private var eventSignatureRecurrence = LongHorizonEventSignatureRecurrenceState()

    private var tensionState = LongHorizonScalarState()
    private var activityState = LongHorizonScalarState()
    private var repetitionState = LongHorizonScalarState()
    private var densityState = LongHorizonScalarState()
    private var tensionDwellState = LongHorizonTensionDwellState()

    private var recentTokens: [LongHorizonSemanticBarToken?] = Array(
        repeating: nil,
        count: LongHorizonSemanticTrajectorySchema.recentSemanticBarCapacity
    )
    private var periodicityStates: [LongHorizonPeriodicityState] = (
        1...LongHorizonSemanticTrajectorySchema.periodicityLagCapacity
    ).map(LongHorizonPeriodicityState.init)

    private var identityLandmarks: [LongHorizonIdentityLandmark?] = Array(
        repeating: nil,
        count: LongHorizonSemanticTrajectorySchema.identityLandmarkCapacity
    )
    private var nextIdentityLandmarkIndex = 0
    private var identityReturnBarCount = 0
    private var matchedHomeSignatureBarCount = 0
    private var unmatchedHomeSignatureBarCount = 0
    private var minimumMatchedAbsenceBars: Int?
    private var maximumMatchedAbsenceBars: Int?
    private var totalMatchedAbsenceBars = 0
    private var matchedAbsenceCount = 0

    private var debtSlots: [LongHorizonDebtSlot?] = Array(
        repeating: nil,
        count: LongHorizonSemanticTrajectorySchema.dramaticDebtCapacity
    )
    private var initialOutstandingDebtCount = 0
    private var debtOpenedCount = 0
    private var debtPaidCount = 0
    private var zeroAgePaidCount = 0
    private var overduePaidCount = 0
    private var maximumOpenDebtCount = 0
    private var maximumObservedDebtAgeBars = 0
    private var debtSourceOpenedCounts = LongHorizonNamedCounterState(
        names: AutonomousPhraseKind.allCases.map(\.rawValue)
    )
    private var debtSourcePaidCounts = LongHorizonNamedCounterState(
        names: AutonomousPhraseKind.allCases.map(\.rawValue)
    )

    package init(startingState: AutonomousSessionState) {
        self.init(
            rootSeed: startingState.rootSeed,
            startingPhraseIndex: startingState.phraseIndex,
            startingBar: startingState.memory.totalBars
        )
        let outstanding = startingState.memory.openDebts
        guard outstanding.count <=
                LongHorizonSemanticTrajectorySchema.dramaticDebtCapacity else {
            terminalReason = .dramaticDebtCapacityExceeded
            return
        }
        let ids = outstanding.map(\.id)
        guard Set(ids).count == ids.count,
              outstanding.allSatisfy({ debt in
                  debt.id >= 0 &&
                      debt.openedAtBar >= 0 &&
                      debt.openedAtBar <= startingState.memory.totalBars &&
                      debt.dueByBar >= debt.openedAtBar &&
                      (debt.source == .contrast || debt.source == .majorBreak)
              }) else {
            terminalReason = .invalidDebt
            return
        }
        for (index, debt) in outstanding.enumerated() {
            debtSlots[index] = LongHorizonDebtSlot(
                id: debt.id,
                openedAtBar: debt.openedAtBar,
                dueByBar: debt.dueByBar,
                source: debt.source
            )
            maximumObservedDebtAgeBars = max(
                maximumObservedDebtAgeBars,
                startingState.memory.totalBars - debt.openedAtBar
            )
        }
        initialOutstandingDebtCount = outstanding.count
        maximumOpenDebtCount = outstanding.count
    }

    package init(
        rootSeed: UInt64,
        startingPhraseIndex: Int,
        startingBar: Int
    ) {
        self.rootSeed = rootSeed
        self.startingPhraseIndex = max(0, startingPhraseIndex)
        self.startingBar = max(0, startingBar)
        nextExpectedPhraseIndex = max(0, startingPhraseIndex)
        nextExpectedBar = max(0, startingBar)
    }

    package mutating func observe(
        plan: AutonomousPhrasePlan,
        incomingState: AutonomousSessionState
    ) -> LongHorizonTrajectoryObservationResult {
        guard terminalReason == nil else {
            return .unavailable(terminalReason!)
        }
        guard incomingState.rootSeed == rootSeed else {
            return becomeUnavailable(.rootSeedMismatch)
        }
        guard incomingState.phraseIndex == nextExpectedPhraseIndex,
              plan.phraseIndex == incomingState.phraseIndex else {
            return becomeUnavailable(.phraseIndexDiscontinuity)
        }
        guard incomingState.memory.totalBars == nextExpectedBar,
              plan.startBar == incomingState.memory.totalBars else {
            return becomeUnavailable(.barDiscontinuity)
        }
        let memoryBars = plan.memoryBars
        guard plan.barCount > 0,
              plan.barCount <= LongHorizonSemanticTrajectorySchema.maximumPhraseBarCount,
              plan.resolvedBars.count == plan.barCount,
              memoryBars.count == plan.barCount,
              plan.phraseComposition.count == plan.barCount,
              plan.performanceCharacterEvidence.valid,
              let character = plan.resolvedBars.first?.performanceCharacter else {
            return becomeUnavailable(.inconsistentCanonicalPlan)
        }

        var bars: [LongHorizonSemanticBarObservation] = []
        bars.reserveCapacity(plan.barCount)
        for index in 0..<plan.barCount {
            let resolved = plan.resolvedBars[index]
            let memory = memoryBars[index]
            let composition = plan.phraseComposition[index]
            guard resolved.performance.bar == plan.startBar + index,
                  resolved.performance.phrase == plan.phraseIndex,
                  resolved.performance.localBar == index,
                  resolved.performance.phraseLength == plan.barCount,
                  resolved.performanceCharacter == character,
                  memory.absoluteBar == resolved.performance.bar,
                  memory.phraseIndex == plan.phraseIndex,
                  composition.bar == resolved.performance.bar else {
                return becomeUnavailable(.inconsistentCanonicalPlan)
            }
            bars.append(Self.semanticBar(
                resolved: resolved,
                memory: memory,
                composition: composition
            ))
        }
        let openedDebt = plan.openedDebt.map {
            LongHorizonSemanticDebtObservation(
                id: $0.id,
                openedAtBar: $0.openedAtBar,
                dueByBar: $0.dueByBar,
                source: $0.source
            )
        }
        return observe(LongHorizonSemanticPhraseObservation(
            rootSeed: incomingState.rootSeed,
            phraseIndex: plan.phraseIndex,
            startBar: plan.startBar,
            kind: plan.kind,
            character: character,
            bars: bars,
            openedDebt: openedDebt,
            paidDebtIDs: plan.paidDebtIDs
        ))
    }

    package mutating func observe(
        _ observation: LongHorizonSemanticPhraseObservation
    ) -> LongHorizonTrajectoryObservationResult {
        guard terminalReason == nil else {
            return .unavailable(terminalReason!)
        }
        guard observation.rootSeed == rootSeed else {
            return becomeUnavailable(.rootSeedMismatch)
        }
        guard observation.phraseIndex == nextExpectedPhraseIndex else {
            return becomeUnavailable(.phraseIndexDiscontinuity)
        }
        guard observation.startBar == nextExpectedBar else {
            return becomeUnavailable(.barDiscontinuity)
        }
        guard !observation.bars.isEmpty else {
            return becomeUnavailable(.emptyPhrase)
        }
        guard observation.bars.count <=
                LongHorizonSemanticTrajectorySchema.maximumPhraseBarCount else {
            return becomeUnavailable(.phraseTooLong)
        }
        guard observation.bars.indices.allSatisfy({ index in
            observation.bars[index].absoluteBar == observation.startBar + index
        }) else {
            return becomeUnavailable(.barDiscontinuity)
        }
        guard observation.bars.allSatisfy(Self.semanticScalarsAreValid) else {
            return becomeUnavailable(.invalidSemanticScalar)
        }
        guard observation.paidDebtIDs.count <=
                LongHorizonSemanticTrajectorySchema.dramaticDebtCapacity,
              Set(observation.paidDebtIDs).count == observation.paidDebtIDs.count
        else {
            return becomeUnavailable(.invalidDebt)
        }

        var proposedDebtSlots = debtSlots
        var proposedOpenedCount = debtOpenedCount
        var proposedPaidCount = debtPaidCount
        var proposedZeroAgePaidCount = zeroAgePaidCount
        var proposedOverduePaidCount = overduePaidCount
        var proposedMaximumObservedDebtAgeBars = maximumObservedDebtAgeBars
        var proposedSourceOpenedCounts = debtSourceOpenedCounts
        var proposedSourcePaidCounts = debtSourcePaidCounts
        let debtResult = Self.applyDebt(
            observation: observation,
            slots: &proposedDebtSlots,
            openedCount: &proposedOpenedCount,
            paidCount: &proposedPaidCount,
            zeroAgePaidCount: &proposedZeroAgePaidCount,
            overduePaidCount: &proposedOverduePaidCount,
            maximumObservedAgeBars: &proposedMaximumObservedDebtAgeBars,
            sourceOpenedCounts: &proposedSourceOpenedCounts,
            sourcePaidCounts: &proposedSourcePaidCounts
        )
        if let debtResult { return becomeUnavailable(debtResult) }

        debtSlots = proposedDebtSlots
        debtOpenedCount = proposedOpenedCount
        debtPaidCount = proposedPaidCount
        zeroAgePaidCount = proposedZeroAgePaidCount
        overduePaidCount = proposedOverduePaidCount
        maximumObservedDebtAgeBars = proposedMaximumObservedDebtAgeBars
        debtSourceOpenedCounts = proposedSourceOpenedCounts
        debtSourcePaidCounts = proposedSourcePaidCounts
        maximumOpenDebtCount = max(
            maximumOpenDebtCount,
            debtSlots.compactMap { $0 }.count
        )

        phraseKindPhraseCounts.increment(observation.kind.rawValue)
        performanceCharacterPhraseCounts.increment(observation.character.rawValue)
        trajectoryHasher.combine("phrase")
        trajectoryHasher.combine(observation.phraseIndex)
        trajectoryHasher.combine(observation.startBar)
        trajectoryHasher.combine(observation.kind.rawValue)
        trajectoryHasher.combine(observation.character.rawValue)

        for bar in observation.bars {
            accumulate(
                bar,
                phraseKind: observation.kind,
                character: observation.character
            )
        }

        observedPhraseCount = longHorizonSaturatingIncrement(observedPhraseCount)
        nextExpectedPhraseIndex = longHorizonSaturatingIncrement(
            nextExpectedPhraseIndex
        )
        nextExpectedBar = longHorizonSaturatingAdd(
            nextExpectedBar,
            observation.bars.count
        )
        for debt in debtSlots.compactMap({ $0 }) {
            maximumObservedDebtAgeBars = max(
                maximumObservedDebtAgeBars,
                max(0, nextExpectedBar - debt.openedAtBar)
            )
        }
        return .accepted
    }

    package func report() -> LongHorizonSemanticTrajectoryReport {
        let reason = terminalReason ?? (observedPhraseCount == 0 ? .noObservations : nil)
        let availability: LongHorizonTrajectoryAvailability = reason == nil
            ? .available : .unavailable
        let periodicity = periodicityStates.map(\.evidence)
        let dominant = periodicity.filter { $0.comparisonCount > 0 }.max { lhs, rhs in
            let left = lhs.semanticMatchRate ?? 0
            let right = rhs.semanticMatchRate ?? 0
            if left != right { return left < right }
            if lhs.semanticMatchCount != rhs.semanticMatchCount {
                return lhs.semanticMatchCount < rhs.semanticMatchCount
            }
            return lhs.lagBars > rhs.lagBars
        }
        let outstanding = debtSlots.compactMap { $0 }
        let overdueOutstanding = outstanding.filter { $0.dueByBar < nextExpectedBar }
        let oldestAge = outstanding.map {
            max(0, nextExpectedBar - $0.openedAtBar)
        }.max() ?? 0
        let recurrenceSlotCount = phraseKindRecurrence.states.count +
            performanceCharacterRecurrence.states.count +
            arrangementGestureRecurrence.states.count +
            transformationRecurrence.states.count +
            signatureEventRecurrence.states.count +
            harmonicFunctionRecurrence.states.count +
            capabilityRecurrence.states.count

        return LongHorizonSemanticTrajectoryReport(
            schemaVersion: LongHorizonSemanticTrajectorySchema.schemaVersion,
            schemaIdentifier: LongHorizonSemanticTrajectorySchema.schemaIdentifier,
            engineVersion: QualityQualificationContract.engineVersion,
            availability: availability,
            unavailableReason: reason,
            qualificationStatus: .unavailable,
            qualificationReason: "no-calibrated-long-horizon-policy",
            rootSeed: rootSeed,
            startingPhraseIndex: startingPhraseIndex,
            startingBar: startingBar,
            nextExpectedPhraseIndex: nextExpectedPhraseIndex,
            nextExpectedBar: nextExpectedBar,
            observedPhraseCount: observedPhraseCount,
            observedBarCount: observedBarCount,
            trajectoryFingerprint: trajectoryHasher.fingerprint,
            phraseKindPhraseCounts: phraseKindPhraseCounts.evidence,
            phraseKindRecurrence: phraseKindRecurrence.evidence,
            performanceCharacterPhraseCounts:
                performanceCharacterPhraseCounts.evidence,
            performanceCharacterRecurrence:
                performanceCharacterRecurrence.evidence,
            sectionBarCounts: sectionBarCounts.evidence,
            roleBarCounts: roleBarCounts.evidence,
            focusRoleBarCounts: focusRoleBarCounts.evidence,
            foundationBehaviorBarCounts: foundationBehaviorBarCounts.evidence,
            arrangementGestureBarCounts: arrangementGestureBarCounts.evidence,
            arrangementGestureRecurrence: arrangementGestureRecurrence.evidence,
            percussionGearBarCounts: percussionGearBarCounts.evidence,
            kickSyntaxRoleBarCounts: kickSyntaxRoleBarCounts.evidence,
            interlockChapterBarCounts: interlockChapterBarCounts.evidence,
            transformationBarCounts: transformationBarCounts.evidence,
            transformationRecurrence: transformationRecurrence.evidence,
            signatureEventBarCounts: signatureEventBarCounts.evidence,
            signatureEventRecurrence: signatureEventRecurrence.evidence,
            harmonicFunctionBarCounts: harmonicFunctionBarCounts.evidence,
            harmonicFunctionRecurrence: harmonicFunctionRecurrence.evidence,
            capabilityRecurrence: capabilityRecurrence.evidence,
            eventSignatureRecurrence: eventSignatureRecurrence.evidence,
            tension: tensionState.evidence,
            activity: activityState.evidence,
            repetition: repetitionState.evidence,
            density: densityState.evidence,
            tensionDwell: tensionDwellState.evidence,
            periodicity: periodicity,
            dominantSemanticPeriodicity: dominant,
            identityRecall: LongHorizonIdentityRecallEvidence(
                landmarkCapacity:
                    LongHorizonSemanticTrajectorySchema.identityLandmarkCapacity,
                landmarkCount: identityLandmarks.compactMap { $0 }.count,
                identityReturnBarCount: identityReturnBarCount,
                matchedHomeSignatureBarCount: matchedHomeSignatureBarCount,
                unmatchedHomeSignatureBarCount: unmatchedHomeSignatureBarCount,
                minimumMatchedAbsenceBars: minimumMatchedAbsenceBars,
                maximumMatchedAbsenceBars: maximumMatchedAbsenceBars,
                meanMatchedAbsenceBars: matchedAbsenceCount > 0
                    ? Double(totalMatchedAbsenceBars) /
                        Double(matchedAbsenceCount) : nil
            ),
            dramaticDebt: LongHorizonDramaticDebtEvidence(
                capacity: LongHorizonSemanticTrajectorySchema.dramaticDebtCapacity,
                initialOutstandingCount: initialOutstandingDebtCount,
                openedCount: debtOpenedCount,
                paidCount: debtPaidCount,
                zeroAgePaidCount: zeroAgePaidCount,
                overduePaidCount: overduePaidCount,
                maximumOpenCount: maximumOpenDebtCount,
                maximumObservedAgeBars: maximumObservedDebtAgeBars,
                outstandingCount: outstanding.count,
                overdueOutstandingCount: overdueOutstanding.count,
                oldestOutstandingAgeBars: oldestAge,
                sourceOpenedCounts: debtSourceOpenedCounts.evidence,
                sourcePaidCounts: debtSourcePaidCounts.evidence
            ),
            storage: LongHorizonTrajectoryStorageEvidence(
                periodicityLagCapacity:
                    LongHorizonSemanticTrajectorySchema.periodicityLagCapacity,
                periodicityLagCount: periodicityStates.count,
                recentSemanticBarCapacity:
                    LongHorizonSemanticTrajectorySchema.recentSemanticBarCapacity,
                recentSemanticBarCount: recentTokens.compactMap { $0 }.count,
                eventSignatureRecurrenceCapacity:
                    LongHorizonSemanticTrajectorySchema
                        .eventSignatureRecurrenceCapacity,
                eventSignatureRecurrenceCount:
                    eventSignatureRecurrence.trackedSignatureCount,
                identityLandmarkCapacity:
                    LongHorizonSemanticTrajectorySchema.identityLandmarkCapacity,
                identityLandmarkCount: identityLandmarks.compactMap { $0 }.count,
                dramaticDebtCapacity:
                    LongHorizonSemanticTrajectorySchema.dramaticDebtCapacity,
                dramaticDebtCount: outstanding.count,
                namedRecurrenceSlotCount: recurrenceSlotCount
            )
        )
    }

    private mutating func accumulate(
        _ bar: LongHorizonSemanticBarObservation,
        phraseKind: AutonomousPhraseKind,
        character: PerformanceCharacter
    ) {
        let semanticFingerprint = Self.semanticFingerprint(
            bar,
            phraseKind: phraseKind,
            character: character
        )
        let token = LongHorizonSemanticBarToken(
            semanticFingerprint: semanticFingerprint,
            eventSignature: bar.eventSignature,
            tensionBand: Self.tensionBand(bar.tension)
        )
        let writeIndex = observedBarCount % recentTokens.count
        let availableLagCount = min(observedBarCount, periodicityStates.count)
        if availableLagCount > 0 {
            for lag in 1...availableLagCount {
                let priorIndex = (writeIndex - lag + recentTokens.count) %
                    recentTokens.count
                if let prior = recentTokens[priorIndex] {
                    periodicityStates[lag - 1].compare(token, with: prior)
                }
            }
        }
        recentTokens[writeIndex] = token

        phraseKindRecurrence.observe(
            activeNames: [phraseKind.rawValue],
            atBar: bar.absoluteBar
        )
        performanceCharacterRecurrence.observe(
            activeNames: [character.rawValue],
            atBar: bar.absoluteBar
        )
        arrangementGestureRecurrence.observe(
            activeNames: [bar.arrangementGesture.rawValue],
            atBar: bar.absoluteBar
        )
        transformationRecurrence.observe(
            activeNames: bar.transformations.map(\.rawValue),
            atBar: bar.absoluteBar
        )
        signatureEventRecurrence.observe(
            activeNames: bar.signatureEvent.map { [$0.rawValue] } ?? [],
            atBar: bar.absoluteBar
        )
        harmonicFunctionRecurrence.observe(
            activeNames: bar.harmonicFunction.map { [$0.rawValue] } ?? [],
            atBar: bar.absoluteBar
        )
        capabilityRecurrence.observe(
            activeNames: bar.capabilities.map(\.rawValue),
            atBar: bar.absoluteBar
        )
        eventSignatureRecurrence.observe(
            signature: bar.eventSignature,
            atBar: bar.absoluteBar
        )

        sectionBarCounts.increment(bar.section.rawValue)
        for role in bar.roles { roleBarCounts.increment(role.rawValue) }
        focusRoleBarCounts.increment(bar.focusRole.rawValue)
        foundationBehaviorBarCounts.increment(bar.foundationBehavior.rawValue)
        arrangementGestureBarCounts.increment(bar.arrangementGesture.rawValue)
        percussionGearBarCounts.increment(bar.percussionGear.rawValue)
        kickSyntaxRoleBarCounts.increment(bar.kickSyntaxRole.rawValue)
        interlockChapterBarCounts.increment(bar.interlockChapter.rawValue)
        for transformation in bar.transformations {
            transformationBarCounts.increment(transformation.rawValue)
        }
        if let signatureEvent = bar.signatureEvent {
            signatureEventBarCounts.increment(signatureEvent.rawValue)
        }
        if let harmonicFunction = bar.harmonicFunction {
            harmonicFunctionBarCounts.increment(harmonicFunction.rawValue)
        }

        tensionState.observe(bar.tension)
        activityState.observe(bar.activity)
        repetitionState.observe(bar.repetition)
        densityState.observe(bar.density)
        tensionDwellState.observe(bar.tension)
        observeIdentity(
            eventSignature: bar.eventSignature,
            atBar: bar.absoluteBar,
            phraseKind: phraseKind,
            character: character
        )

        trajectoryHasher.combine("bar")
        trajectoryHasher.combine(bar.absoluteBar)
        trajectoryHasher.combine(semanticFingerprint)
        trajectoryHasher.combine(bar.eventSignature)
        observedBarCount = longHorizonSaturatingIncrement(observedBarCount)
    }

    private mutating func observeIdentity(
        eventSignature: UInt64,
        atBar bar: Int,
        phraseKind: AutonomousPhraseKind,
        character: PerformanceCharacter
    ) {
        if phraseKind == .lock && character == .hypnoticLock {
            guard !identityLandmarks.contains(where: {
                $0?.eventSignature == eventSignature
            }) else {
                return
            }
            identityLandmarks[nextIdentityLandmarkIndex] = LongHorizonIdentityLandmark(
                eventSignature: eventSignature,
                establishedAtBar: bar
            )
            nextIdentityLandmarkIndex = (nextIdentityLandmarkIndex + 1) %
                identityLandmarks.count
        } else if phraseKind == .identityReturn {
            identityReturnBarCount = longHorizonSaturatingIncrement(
                identityReturnBarCount
            )
            if let landmark = identityLandmarks.compactMap({ $0 }).first(where: {
                $0.eventSignature == eventSignature
            }) {
                matchedHomeSignatureBarCount = longHorizonSaturatingIncrement(
                    matchedHomeSignatureBarCount
                )
                let absence = Self.nonnegativeDistance(
                    from: landmark.establishedAtBar,
                    to: bar
                )
                minimumMatchedAbsenceBars = min(
                    minimumMatchedAbsenceBars ?? absence,
                    absence
                )
                maximumMatchedAbsenceBars = max(
                    maximumMatchedAbsenceBars ?? absence,
                    absence
                )
                totalMatchedAbsenceBars = longHorizonSaturatingAdd(
                    totalMatchedAbsenceBars,
                    absence
                )
                matchedAbsenceCount = longHorizonSaturatingIncrement(
                    matchedAbsenceCount
                )
            } else {
                unmatchedHomeSignatureBarCount = longHorizonSaturatingIncrement(
                    unmatchedHomeSignatureBarCount
                )
            }
        }
    }

    private static func nonnegativeDistance(from start: Int, to end: Int) -> Int {
        guard end >= start else { return 0 }
        return end - start
    }

    private mutating func becomeUnavailable(
        _ reason: LongHorizonTrajectoryUnavailableReason
    ) -> LongHorizonTrajectoryObservationResult {
        terminalReason = reason
        return .unavailable(reason)
    }

    private static func semanticScalarsAreValid(
        _ bar: LongHorizonSemanticBarObservation
    ) -> Bool {
        [bar.tension, bar.activity, bar.repetition, bar.density].allSatisfy {
            $0.isFinite && (0...1).contains($0)
        }
    }

    private static func applyDebt(
        observation: LongHorizonSemanticPhraseObservation,
        slots: inout [LongHorizonDebtSlot?],
        openedCount: inout Int,
        paidCount: inout Int,
        zeroAgePaidCount: inout Int,
        overduePaidCount: inout Int,
        maximumObservedAgeBars: inout Int,
        sourceOpenedCounts: inout LongHorizonNamedCounterState,
        sourcePaidCounts: inout LongHorizonNamedCounterState
    ) -> LongHorizonTrajectoryUnavailableReason? {
        if let opened = observation.openedDebt {
            guard opened.id >= 0,
                  opened.openedAtBar == observation.startBar,
                  opened.dueByBar >= opened.openedAtBar,
                  opened.source == observation.kind,
                  !slots.contains(where: { $0?.id == opened.id }) else {
                return .invalidDebt
            }
            guard let free = slots.firstIndex(where: { $0 == nil }) else {
                return .dramaticDebtCapacityExceeded
            }
            slots[free] = LongHorizonDebtSlot(
                id: opened.id,
                openedAtBar: opened.openedAtBar,
                dueByBar: opened.dueByBar,
                source: opened.source
            )
            openedCount = longHorizonSaturatingIncrement(openedCount)
            sourceOpenedCounts.increment(opened.source.rawValue)
        }

        for id in observation.paidDebtIDs {
            guard let index = slots.firstIndex(where: { $0?.id == id }),
                  let debt = slots[index] else {
                return .unknownPaidDebt
            }
            let age = max(0, observation.startBar - debt.openedAtBar)
            maximumObservedAgeBars = max(maximumObservedAgeBars, age)
            if age == 0 {
                zeroAgePaidCount = longHorizonSaturatingIncrement(zeroAgePaidCount)
            }
            if observation.startBar > debt.dueByBar {
                overduePaidCount = longHorizonSaturatingIncrement(overduePaidCount)
            }
            paidCount = longHorizonSaturatingIncrement(paidCount)
            sourcePaidCounts.increment(debt.source.rawValue)
            slots[index] = nil
        }
        return nil
    }

    private static func semanticBar(
        resolved: ResolvedPerformanceBar,
        memory: MusicalMemoryBar,
        composition: PhraseCompositionBar
    ) -> LongHorizonSemanticBarObservation {
        LongHorizonSemanticBarObservation(
            absoluteBar: memory.absoluteBar,
            section: memory.section,
            tension: memory.tension,
            roles: memory.roles,
            transformations: memory.transformations,
            eventSignature: memory.eventSignature,
            activity: memory.activity,
            repetition: memory.repetition,
            density: memory.density,
            focusRole: resolved.ensemble.focusRole,
            foundationBehavior: resolved.foundationBehavior,
            arrangementGesture: resolved.arrangementGesture,
            percussionGear: resolved.percussionGear,
            kickSyntaxRole: resolved.kickSyntaxRole,
            interlockChapter: resolved.interlockChapter,
            signatureEvent: resolved.performance.signatureEvent,
            harmonicFunction: composition.padVoicing?.function,
            capabilities: semanticCapabilities(
                resolved: resolved,
                composition: composition
            )
        )
    }

    private static func semanticCapabilities(
        resolved: ResolvedPerformanceBar,
        composition: PhraseCompositionBar
    ) -> [LongHorizonSemanticCapability] {
        var result: [LongHorizonSemanticCapability] = []
        func add(_ capability: LongHorizonSemanticCapability, when condition: Bool) {
            if condition { result.append(capability) }
        }
        add(.groovePulse, when: !resolved.groovePulses.isEmpty)
        add(.closedHatCompanion, when: resolved.closedHatDecayArticulations.contains {
            $0.role == .openHatCompanion
        })
        add(.upperPercussionClearance,
            when: resolved.upperPercussionTailArticulations.contains {
                $0.role == .foregroundClearance
            })
        add(.modalPercussion, when: !resolved.modalPercussionArticulations.isEmpty)
        add(.spatialDistance, when: resolved.spatialContrast.depthPosition == .distant)
        add(.pulseEcho, when: resolved.pulseEchoEnabled)
        add(.dottedFoundationRhythm,
            when: resolved.foundationRhythmicRelation == .dottedThreeSixteenth)
        add(.kickWithholding, when: resolved.kickSyntaxRole == .withheld)
        add(.kickRecovery, when: resolved.kickSyntaxRole == .recovery)
        add(.climaxHang, when: resolved.climaxHang != nil)
        if let percussion = resolved.percussionEchoTexture {
            add(.gatedPercussionEcho, when: percussion.relation == .gatedEcho)
            add(.anticipationSwell, when: percussion.relation == .anticipationSwell)
        }
        add(.audioSlice, when: composition.audioSlice != nil)
        add(.arpeggiator, when: composition.arpeggiator != nil)
        if let pad = composition.padVoicing {
            add(.padHarmony, when: true)
            add(.harmonicDisclosure,
                when: pad.harmonicDisclosureStage != .established)
            add(.padRhythmicModulation, when: pad.rhythmicModulation.active)
        }
        return LongHorizonSemanticCapability.allCases.filter(result.contains)
    }

    private static func semanticFingerprint(
        _ bar: LongHorizonSemanticBarObservation,
        phraseKind: AutonomousPhraseKind,
        character: PerformanceCharacter
    ) -> UInt64 {
        var hasher = LongHorizonSemanticHasher()
        hasher.combine(phraseKind.rawValue)
        hasher.combine(character.rawValue)
        hasher.combine(bar.section.rawValue)
        hasher.combine(bar.focusRole.rawValue)
        hasher.combine(bar.foundationBehavior.rawValue)
        hasher.combine(bar.arrangementGesture.rawValue)
        hasher.combine(bar.percussionGear.rawValue)
        hasher.combine(bar.kickSyntaxRole.rawValue)
        hasher.combine(bar.interlockChapter.rawValue)
        hasher.combine(bar.signatureEvent?.rawValue ?? "none")
        hasher.combine(bar.harmonicFunction?.rawValue ?? "none")
        hasher.combine(tensionBand(bar.tension))
        hasher.combine(bar.roles.count)
        for role in bar.roles { hasher.combine(role.rawValue) }
        hasher.combine(bar.transformations.count)
        for transformation in bar.transformations {
            hasher.combine(transformation.rawValue)
        }
        hasher.combine(bar.capabilities.count)
        for capability in bar.capabilities { hasher.combine(capability.rawValue) }
        return hasher.value
    }

    private static func tensionBand(_ tension: Double) -> Int {
        min(10, max(0, Int((tension * 10).rounded(.down))))
    }
}

private struct LongHorizonSemanticBarToken: Sendable {
    let semanticFingerprint: UInt64
    let eventSignature: UInt64
    let tensionBand: Int
}

private struct LongHorizonPeriodicityState: Sendable {
    let lagBars: Int
    var comparisonCount = 0
    var semanticMatchCount = 0
    var eventSignatureMatchCount = 0
    var tensionBandMatchCount = 0

    init(_ lagBars: Int) {
        self.lagBars = lagBars
    }

    mutating func compare(
        _ current: LongHorizonSemanticBarToken,
        with prior: LongHorizonSemanticBarToken
    ) {
        comparisonCount = longHorizonSaturatingIncrement(comparisonCount)
        if current.semanticFingerprint == prior.semanticFingerprint {
            semanticMatchCount = longHorizonSaturatingIncrement(semanticMatchCount)
        }
        if current.eventSignature == prior.eventSignature {
            eventSignatureMatchCount = longHorizonSaturatingIncrement(
                eventSignatureMatchCount
            )
        }
        if current.tensionBand == prior.tensionBand {
            tensionBandMatchCount = longHorizonSaturatingIncrement(
                tensionBandMatchCount
            )
        }
    }

    var evidence: LongHorizonPeriodicityLagEvidence {
        func rate(_ count: Int) -> Double? {
            comparisonCount > 0 ? Double(count) / Double(comparisonCount) : nil
        }
        return LongHorizonPeriodicityLagEvidence(
            lagBars: lagBars,
            comparisonCount: comparisonCount,
            semanticMatchCount: semanticMatchCount,
            eventSignatureMatchCount: eventSignatureMatchCount,
            tensionBandMatchCount: tensionBandMatchCount,
            semanticMatchRate: rate(semanticMatchCount),
            eventSignatureMatchRate: rate(eventSignatureMatchCount),
            tensionBandMatchRate: rate(tensionBandMatchCount)
        )
    }
}

private struct LongHorizonNamedCounterState: Sendable {
    private var entries: [(name: String, count: Int)]

    init(names: [String]) {
        entries = names.map { ($0, 0) }
    }

    mutating func increment(_ name: String) {
        guard let index = entries.firstIndex(where: { $0.name == name }) else {
            return
        }
        entries[index].count = longHorizonSaturatingIncrement(entries[index].count)
    }

    var evidence: [LongHorizonNamedCount] {
        entries.map(LongHorizonNamedCount.init)
    }
}

private struct LongHorizonNamedRecurrenceState: Sendable {
    let name: String
    var activeBarCount = 0
    var activationCount = 0
    var currentRunBars = 0
    var maximumRunBars = 0
    var minimumInactiveGapBars: Int?
    var maximumInactiveGapBars: Int?
    var totalInactiveGapBars = 0
    var inactiveGapCount = 0
    var firstActiveBar: Int?
    var lastActiveBar: Int?
    var wasActive = false

    mutating func observe(active: Bool, atBar bar: Int) {
        guard active else {
            currentRunBars = 0
            wasActive = false
            return
        }
        activeBarCount = longHorizonSaturatingIncrement(activeBarCount)
        if wasActive {
            currentRunBars = longHorizonSaturatingIncrement(currentRunBars)
        } else {
            activationCount = longHorizonSaturatingIncrement(activationCount)
            currentRunBars = 1
            if let lastActiveBar {
                let gap = max(0, bar - lastActiveBar - 1)
                minimumInactiveGapBars = min(minimumInactiveGapBars ?? gap, gap)
                maximumInactiveGapBars = max(maximumInactiveGapBars ?? gap, gap)
                totalInactiveGapBars = longHorizonSaturatingAdd(
                    totalInactiveGapBars,
                    gap
                )
                inactiveGapCount = longHorizonSaturatingIncrement(inactiveGapCount)
            }
        }
        maximumRunBars = max(maximumRunBars, currentRunBars)
        firstActiveBar = firstActiveBar ?? bar
        lastActiveBar = bar
        wasActive = true
    }

    var evidence: LongHorizonNamedRecurrenceEvidence {
        LongHorizonNamedRecurrenceEvidence(
            name: name,
            activeBarCount: activeBarCount,
            activationCount: activationCount,
            currentRunBars: currentRunBars,
            maximumRunBars: maximumRunBars,
            minimumInactiveGapBars: minimumInactiveGapBars,
            maximumInactiveGapBars: maximumInactiveGapBars,
            meanInactiveGapBars: inactiveGapCount > 0
                ? Double(totalInactiveGapBars) / Double(inactiveGapCount) : nil,
            firstActiveBar: firstActiveBar,
            lastActiveBar: lastActiveBar
        )
    }
}

private struct LongHorizonNamedRecurrenceCollection: Sendable {
    fileprivate var states: [LongHorizonNamedRecurrenceState]

    init(names: [String]) {
        states = names.map { LongHorizonNamedRecurrenceState(name: $0) }
    }

    mutating func observe(activeNames: [String], atBar bar: Int) {
        for index in states.indices {
            states[index].observe(
                active: activeNames.contains(states[index].name),
                atBar: bar
            )
        }
    }

    var evidence: [LongHorizonNamedRecurrenceEvidence] {
        states.map(\.evidence)
    }
}

private struct LongHorizonScalarState: Sendable {
    var observationCount = 0
    var first: Double?
    var last: Double?
    var minimum: Double?
    var maximum: Double?
    var mean: Double?
    var maximumAbsoluteStep = 0.0
    var previousDirection = 0
    var directionChangeCount = 0

    mutating func observe(_ value: Double) {
        if let last {
            let delta = value - last
            maximumAbsoluteStep = max(maximumAbsoluteStep, abs(delta))
            let direction = delta > 0 ? 1 : (delta < 0 ? -1 : 0)
            if direction != 0,
               previousDirection != 0,
               direction != previousDirection {
                directionChangeCount = longHorizonSaturatingIncrement(
                    directionChangeCount
                )
            }
            if direction != 0 { previousDirection = direction }
        }
        observationCount = longHorizonSaturatingIncrement(observationCount)
        first = first ?? value
        last = value
        minimum = min(minimum ?? value, value)
        maximum = max(maximum ?? value, value)
        if let oldMean = mean {
            mean = oldMean + (value - oldMean) / Double(observationCount)
        } else {
            mean = value
        }
    }

    var evidence: LongHorizonScalarTrajectoryEvidence {
        LongHorizonScalarTrajectoryEvidence(
            observationCount: observationCount,
            first: first,
            last: last,
            minimum: minimum,
            maximum: maximum,
            mean: mean,
            maximumAbsoluteStep: maximumAbsoluteStep,
            directionChangeCount: directionChangeCount
        )
    }
}

private struct LongHorizonTensionDwellState: Sendable {
    var highBarCount = 0
    var recoveryBarCount = 0
    var currentHighDwellBars = 0
    var maximumHighDwellBars = 0
    var currentRecoveryDwellBars = 0
    var maximumRecoveryDwellBars = 0

    mutating func observe(_ tension: Double) {
        if tension >= LongHorizonSemanticTrajectorySchema.highTensionObservationFloor {
            highBarCount = longHorizonSaturatingIncrement(highBarCount)
            currentHighDwellBars = longHorizonSaturatingIncrement(
                currentHighDwellBars
            )
            maximumHighDwellBars = max(
                maximumHighDwellBars,
                currentHighDwellBars
            )
        } else {
            currentHighDwellBars = 0
        }
        if tension <=
                LongHorizonSemanticTrajectorySchema.recoveryTensionObservationCeiling {
            recoveryBarCount = longHorizonSaturatingIncrement(recoveryBarCount)
            currentRecoveryDwellBars = longHorizonSaturatingIncrement(
                currentRecoveryDwellBars
            )
            maximumRecoveryDwellBars = max(
                maximumRecoveryDwellBars,
                currentRecoveryDwellBars
            )
        } else {
            currentRecoveryDwellBars = 0
        }
    }

    var evidence: LongHorizonTensionDwellEvidence {
        LongHorizonTensionDwellEvidence(
            highObservationFloor:
                LongHorizonSemanticTrajectorySchema.highTensionObservationFloor,
            recoveryObservationCeiling:
                LongHorizonSemanticTrajectorySchema.recoveryTensionObservationCeiling,
            highBarCount: highBarCount,
            recoveryBarCount: recoveryBarCount,
            currentHighDwellBars: currentHighDwellBars,
            maximumHighDwellBars: maximumHighDwellBars,
            currentRecoveryDwellBars: currentRecoveryDwellBars,
            maximumRecoveryDwellBars: maximumRecoveryDwellBars
        )
    }
}

private struct LongHorizonEventSignatureRecurrenceState: Sendable {
    private var slots: [LongHorizonEventSignatureSlot?] = Array(
        repeating: nil,
        count: LongHorizonSemanticTrajectorySchema.eventSignatureRecurrenceCapacity
    )
    private(set) var observationCount = 0
    private(set) var repeatObservationCount = 0
    private(set) var recurrenceGapCount = 0
    private var minimumInactiveGapBars: Int?
    private var maximumInactiveGapBars: Int?
    private var totalInactiveGapBars = 0
    private var maximumRunBars = 0
    private var evictionCount = 0

    var trackedSignatureCount: Int {
        slots.compactMap { $0 }.count
    }

    mutating func observe(signature: UInt64, atBar bar: Int) {
        observationCount = longHorizonSaturatingIncrement(observationCount)
        if let index = slots.firstIndex(where: { $0?.signature == signature }),
           var slot = slots[index] {
            repeatObservationCount = longHorizonSaturatingIncrement(
                repeatObservationCount
            )
            let gap = max(0, bar - slot.lastActiveBar - 1)
            if gap == 0 {
                slot.currentRunBars = longHorizonSaturatingIncrement(
                    slot.currentRunBars
                )
            } else {
                recurrenceGapCount = longHorizonSaturatingIncrement(
                    recurrenceGapCount
                )
                minimumInactiveGapBars = min(minimumInactiveGapBars ?? gap, gap)
                maximumInactiveGapBars = max(maximumInactiveGapBars ?? gap, gap)
                totalInactiveGapBars = longHorizonSaturatingAdd(
                    totalInactiveGapBars,
                    gap
                )
                slot.currentRunBars = 1
            }
            maximumRunBars = max(maximumRunBars, slot.currentRunBars)
            slot.lastActiveBar = bar
            slots[index] = slot
            return
        }

        let insertionIndex: Int
        if let free = slots.firstIndex(where: { $0 == nil }) {
            insertionIndex = free
        } else {
            insertionIndex = slots.indices.min {
                (slots[$0]?.lastActiveBar ?? Int.max) <
                    (slots[$1]?.lastActiveBar ?? Int.max)
            } ?? 0
            evictionCount = longHorizonSaturatingIncrement(evictionCount)
        }
        slots[insertionIndex] = LongHorizonEventSignatureSlot(
            signature: signature,
            lastActiveBar: bar,
            currentRunBars: 1
        )
        maximumRunBars = max(maximumRunBars, 1)
    }

    var evidence: LongHorizonEventSignatureRecurrenceEvidence {
        LongHorizonEventSignatureRecurrenceEvidence(
            capacity:
                LongHorizonSemanticTrajectorySchema.eventSignatureRecurrenceCapacity,
            trackedSignatureCount: trackedSignatureCount,
            observationCount: observationCount,
            repeatObservationCount: repeatObservationCount,
            recurrenceGapCount: recurrenceGapCount,
            minimumInactiveGapBars: minimumInactiveGapBars,
            maximumInactiveGapBars: maximumInactiveGapBars,
            meanInactiveGapBars: recurrenceGapCount > 0
                ? Double(totalInactiveGapBars) / Double(recurrenceGapCount) : nil,
            maximumRunBars: maximumRunBars,
            evictionCount: evictionCount
        )
    }
}

private struct LongHorizonEventSignatureSlot: Sendable {
    let signature: UInt64
    var lastActiveBar: Int
    var currentRunBars: Int
}

private struct LongHorizonIdentityLandmark: Sendable {
    let eventSignature: UInt64
    let establishedAtBar: Int
}

private struct LongHorizonDebtSlot: Sendable {
    let id: Int
    let openedAtBar: Int
    let dueByBar: Int
    let source: AutonomousPhraseKind
}

private struct LongHorizonSemanticHasher: Sendable {
    fileprivate var value: UInt64 = 0xcbf2_9ce4_8422_2325

    var fingerprint: String {
        let raw = String(value, radix: 16)
        return String(repeating: "0", count: 16 - raw.count) + raw
    }

    mutating func combine(_ value: String) {
        for byte in value.utf8 { combine(byte) }
        combine(0xff)
    }

    mutating func combine(_ value: Int) {
        combine(UInt64(bitPattern: Int64(value)))
    }

    mutating func combine(_ value: UInt64) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { bytes in
            for byte in bytes { combine(byte) }
        }
    }

    private mutating func combine(_ byte: UInt8) {
        value ^= UInt64(byte)
        value = value &* 0x0000_0100_0000_01b3
    }
}

private func longHorizonSaturatingIncrement(_ value: Int) -> Int {
    value == Int.max ? Int.max : value + 1
}

private func longHorizonSaturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
    guard rhs > 0 else { return lhs }
    return lhs > Int.max - rhs ? Int.max : lhs + rhs
}
