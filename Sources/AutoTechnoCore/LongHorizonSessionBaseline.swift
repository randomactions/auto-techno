import Foundation

/// Fixed, detached geometry for a neutral long-session planning observatory.
/// Nothing in this contract selects, rejects, adapts, or renders music.
package enum LongHorizonSessionBaselineSchema {
    package static let schemaVersion = 1
    package static let schemaIdentifier =
        "autotechno-long-horizon-session-baseline.v1"
    package static let maximumBarCount = 8_192
    package static let segmentBarCount = 32
    package static let maximumSegmentCount =
        maximumBarCount / segmentBarCount
    package static let highTensionObservationFloor =
        LongHorizonSemanticTrajectorySchema.highTensionObservationFloor
    package static let recoveryTensionObservationCeiling =
        LongHorizonSemanticTrajectorySchema.recoveryTensionObservationCeiling
    package static let qualificationReason =
        "descriptive-score-only-no-quality-rank"
    package static let realizedSignalUnavailableReason =
        "score-only-no-continuous-pcm"
}

package enum LongHorizonSessionBaselineUnavailableReason: String, Codable,
        Sendable {
    case noObservations = "no-observations"
    case rootSeedMismatch = "root-seed-mismatch"
    case phraseIndexDiscontinuity = "phrase-index-discontinuity"
    case barDiscontinuity = "bar-discontinuity"
    case emptyPhrase = "empty-phrase"
    case phraseTooLong = "phrase-too-long"
    case barCapacityExceeded = "bar-capacity-exceeded"
    case inconsistentSelection = "inconsistent-selection"
    case invalidScalar = "invalid-scalar"
    case invalidCapabilityOrder = "invalid-capability-order"
}

package enum LongHorizonSessionBaselineAnalysisResult: Equatable, Sendable {
    case available(LongHorizonSessionBaselineReport)
    case unavailable(LongHorizonSessionBaselineUnavailableReason)
}

package struct LongHorizonSessionBaselineBarInput: Codable, Equatable,
        Sendable {
    private enum CodingKeys: String, CodingKey {
        case absoluteBar
        case section
        case interlockChapter
        case tension
        case activity
        case repetition
        case density
        case eventSignature
        case capabilities
    }

    package let absoluteBar: Int
    package let section: SectionKind
    package let interlockChapter: InterlockChapter
    package let tension: Double
    package let activity: Double
    package let repetition: Double
    package let density: Double
    package let eventSignature: UInt64
    package let capabilities: [LongHorizonSemanticCapability]

    package init(
        absoluteBar: Int,
        section: SectionKind = .groove,
        interlockChapter: InterlockChapter = .home,
        tension: Double,
        activity: Double,
        repetition: Double,
        density: Double,
        eventSignature: UInt64,
        capabilities: [LongHorizonSemanticCapability]
    ) {
        self.absoluteBar = absoluteBar
        self.section = section
        self.interlockChapter = interlockChapter
        self.tension = tension
        self.activity = activity
        self.repetition = repetition
        self.density = density
        self.eventSignature = eventSignature
        self.capabilities = LongHorizonSemanticCapability.allCases.filter(
            capabilities.contains
        )
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        absoluteBar = try container.decode(Int.self, forKey: .absoluteBar)
        let sectionValue = try container.decode(String.self, forKey: .section)
        guard let decodedSection = SectionKind(rawValue: sectionValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .section,
                in: container,
                debugDescription: "Unknown section kind: \(sectionValue)"
            )
        }
        section = decodedSection
        let chapterValue = try container.decode(
            String.self,
            forKey: .interlockChapter
        )
        guard let decodedChapter = InterlockChapter(rawValue: chapterValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .interlockChapter,
                in: container,
                debugDescription: "Unknown interlock chapter: \(chapterValue)"
            )
        }
        interlockChapter = decodedChapter
        tension = try container.decode(Double.self, forKey: .tension)
        activity = try container.decode(Double.self, forKey: .activity)
        repetition = try container.decode(Double.self, forKey: .repetition)
        density = try container.decode(Double.self, forKey: .density)
        eventSignature = try container.decode(
            UInt64.self,
            forKey: .eventSignature
        )
        capabilities = try container.decode(
            [LongHorizonSemanticCapability].self,
            forKey: .capabilities
        )
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(absoluteBar, forKey: .absoluteBar)
        try container.encode(section.rawValue, forKey: .section)
        try container.encode(
            interlockChapter.rawValue,
            forKey: .interlockChapter
        )
        try container.encode(tension, forKey: .tension)
        try container.encode(activity, forKey: .activity)
        try container.encode(repetition, forKey: .repetition)
        try container.encode(density, forKey: .density)
        try container.encode(eventSignature, forKey: .eventSignature)
        try container.encode(capabilities, forKey: .capabilities)
    }
}

package struct LongHorizonSessionBaselinePhraseInput: Codable, Equatable,
        Sendable {
    private enum CodingKeys: String, CodingKey {
        case rootSeed
        case phraseIndex
        case startBar
        case phraseKind
        case operatorKind
        case selectionReason
        case bars
    }

    package let rootSeed: UInt64
    package let phraseIndex: Int
    package let startBar: Int
    package let phraseKind: AutonomousPhraseKind
    package let operatorKind: LongHorizonEpisodeOperator?
    package let selectionReason: LongHorizonPhraseSelectionReason
    package let bars: [LongHorizonSessionBaselineBarInput]

    package init(
        rootSeed: UInt64,
        phraseIndex: Int,
        startBar: Int,
        phraseKind: AutonomousPhraseKind,
        operatorKind: LongHorizonEpisodeOperator?,
        selectionReason: LongHorizonPhraseSelectionReason,
        bars: [LongHorizonSessionBaselineBarInput]
    ) {
        self.rootSeed = rootSeed
        self.phraseIndex = phraseIndex
        self.startBar = startBar
        self.phraseKind = phraseKind
        self.operatorKind = operatorKind
        self.selectionReason = selectionReason
        self.bars = bars
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rootSeed = try container.decode(UInt64.self, forKey: .rootSeed)
        phraseIndex = try container.decode(Int.self, forKey: .phraseIndex)
        startBar = try container.decode(Int.self, forKey: .startBar)
        phraseKind = try container.decode(
            AutonomousPhraseKind.self,
            forKey: .phraseKind
        )
        operatorKind = try container.decode(
            LongHorizonEpisodeOperator?.self,
            forKey: .operatorKind
        )
        selectionReason = try container.decode(
            LongHorizonPhraseSelectionReason.self,
            forKey: .selectionReason
        )
        bars = try container.decode(
            [LongHorizonSessionBaselineBarInput].self,
            forKey: .bars
        )
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rootSeed, forKey: .rootSeed)
        try container.encode(phraseIndex, forKey: .phraseIndex)
        try container.encode(startBar, forKey: .startBar)
        try container.encode(phraseKind, forKey: .phraseKind)
        try container.encode(operatorKind, forKey: .operatorKind)
        try container.encode(selectionReason, forKey: .selectionReason)
        try container.encode(bars, forKey: .bars)
    }

    package static func make(
        plan: AutonomousPhrasePlan,
        incomingState: AutonomousSessionState
    ) -> LongHorizonSessionBaselinePhraseInput? {
        let memory = plan.memoryBars
        guard plan.dna == incomingState.identityDNA,
              incomingState.phraseIndex == plan.phraseIndex,
              incomingState.memory.totalBars == plan.startBar,
              plan.barCount > 0,
              plan.barCount <=
                LongHorizonSemanticTrajectorySchema.maximumPhraseBarCount,
              memory.count == plan.barCount,
              plan.resolvedBars.count == plan.barCount,
              plan.phraseComposition.count == plan.barCount,
              plan.longHorizonSelection.phraseKind == plan.kind,
              plan.longHorizonEnergyCoordination.isConsistent(
                phraseIndex: plan.phraseIndex,
                startBar: plan.startBar,
                phraseKind: plan.kind,
                selection: plan.longHorizonSelection
              ) else {
            return nil
        }
        var bars: [LongHorizonSessionBaselineBarInput] = []
        bars.reserveCapacity(plan.barCount)
        for index in 0..<plan.barCount {
            let source = memory[index]
            let resolved = plan.resolvedBars[index]
            let composition = plan.phraseComposition[index]
            guard source.absoluteBar == plan.startBar + index,
                  source.phraseIndex == plan.phraseIndex,
                  resolved.performance.bar == source.absoluteBar,
                  resolved.performance.phrase == plan.phraseIndex,
                  resolved.performance.localBar == index,
                  composition.bar == source.absoluteBar else {
                return nil
            }
            bars.append(LongHorizonSessionBaselineBarInput(
                absoluteBar: source.absoluteBar,
                section: source.section,
                interlockChapter: resolved.interlockChapter,
                tension: source.tension,
                activity: source.activity,
                repetition: source.repetition,
                density: source.density,
                eventSignature: source.eventSignature,
                capabilities:
                    LongHorizonSemanticTrajectoryAccumulator
                        .semanticCapabilities(
                            resolved: resolved,
                            composition: composition
                        )
            ))
        }
        return LongHorizonSessionBaselinePhraseInput(
            rootSeed: incomingState.rootSeed,
            phraseIndex: plan.phraseIndex,
            startBar: plan.startBar,
            phraseKind: plan.kind,
            operatorKind: plan.longHorizonSelection.operatorKind,
            selectionReason: plan.longHorizonSelection.reason,
            bars: bars
        )
    }
}

package struct LongHorizonSessionNamedBarCount: Codable, Equatable, Sendable {
    package let name: String
    package let barCount: Int
}

package struct LongHorizonSessionScalarSummary: Codable, Equatable, Sendable {
    package let observationCount: Int
    package let first: Double
    package let last: Double
    package let minimum: Double
    package let maximum: Double
    package let mean: Double
    package let maximumAbsoluteStep: Double
    package let directionChangeCount: Int
}

package struct LongHorizonSessionCapabilityExposure: Codable, Equatable,
        Sendable {
    package let capability: LongHorizonSemanticCapability
    package let activeBarCount: Int
    package let maximumRunBars: Int
}

package struct LongHorizonSessionSpacingEvidence: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case intervalCount
        case minimumBars
        case maximumBars
        case meanBars
    }

    package let intervalCount: Int
    package let minimumBars: Int?
    package let maximumBars: Int?
    package let meanBars: Double?

    package init(
        intervalCount: Int,
        minimumBars: Int?,
        maximumBars: Int?,
        meanBars: Double?
    ) {
        self.intervalCount = intervalCount
        self.minimumBars = minimumBars
        self.maximumBars = maximumBars
        self.meanBars = meanBars
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intervalCount = try container.decode(Int.self, forKey: .intervalCount)
        minimumBars = try container.decode(Int?.self, forKey: .minimumBars)
        maximumBars = try container.decode(Int?.self, forKey: .maximumBars)
        meanBars = try container.decode(Double?.self, forKey: .meanBars)
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(intervalCount, forKey: .intervalCount)
        try container.encode(minimumBars, forKey: .minimumBars)
        try container.encode(maximumBars, forKey: .maximumBars)
        try container.encode(meanBars, forKey: .meanBars)
    }
}

package enum LongHorizonSessionPayoffRecoveryStatus: String, Codable, Sendable {
    case observed
    case unresolvedWithinHorizon = "unresolved-within-horizon"
}

package struct LongHorizonSessionPayoffRecoveryEvidence: Codable, Equatable,
        Sendable {
    private enum CodingKeys: String, CodingKey {
        case payoffBar
        case recoveryBar
        case latencyBars
        case status
    }

    package let payoffBar: Int
    package let recoveryBar: Int?
    package let latencyBars: Int?
    package let status: LongHorizonSessionPayoffRecoveryStatus

    package init(
        payoffBar: Int,
        recoveryBar: Int?,
        latencyBars: Int?,
        status: LongHorizonSessionPayoffRecoveryStatus
    ) {
        self.payoffBar = payoffBar
        self.recoveryBar = recoveryBar
        self.latencyBars = latencyBars
        self.status = status
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        payoffBar = try container.decode(Int.self, forKey: .payoffBar)
        recoveryBar = try container.decode(Int?.self, forKey: .recoveryBar)
        latencyBars = try container.decode(Int?.self, forKey: .latencyBars)
        status = try container.decode(
            LongHorizonSessionPayoffRecoveryStatus.self,
            forKey: .status
        )
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(payoffBar, forKey: .payoffBar)
        try container.encode(recoveryBar, forKey: .recoveryBar)
        try container.encode(latencyBars, forKey: .latencyBars)
        try container.encode(status, forKey: .status)
    }
}

package struct LongHorizonSessionSegmentEvidence: Codable, Equatable, Sendable {
    package let segmentIndex: Int
    package let startBar: Int
    package let endBarExclusive: Int
    package let barCount: Int
    package let complete: Bool
    package let tension: LongHorizonSessionScalarSummary
    package let activity: LongHorizonSessionScalarSummary
    package let repetition: LongHorizonSessionScalarSummary
    package let density: LongHorizonSessionScalarSummary
    package let highTensionBarCount: Int
    package let recoveryTensionBarCount: Int
    package let maximumHighTensionRunBars: Int
    package let payoffMarkerBars: [Int]
    package let recoveryMarkerBars: [Int]
    package let repeatedEventSignatureBarCount: Int
    package let maximumEventSignatureRunBars: Int
    package let phraseKindBarCounts: [LongHorizonSessionNamedBarCount]
    package let operatorBarCounts: [LongHorizonSessionNamedBarCount]
    package let sectionBarCounts: [LongHorizonSessionNamedBarCount]
    package let interlockChapterBarCounts: [LongHorizonSessionNamedBarCount]
    package let capabilityExposure: [LongHorizonSessionCapabilityExposure]
}

/// Descriptive session evidence. `qualificationStatus` and realized-signal
/// availability are intentionally negative so this cannot masquerade as a
/// calibrated listener-fatigue or professional-quality verdict.
package struct LongHorizonSessionBaselineReport: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let schemaIdentifier: String
    package let engineVersion: String
    package let qualificationStatus: String
    package let qualificationReason: String
    package let realizedSignalAvailability: String
    package let realizedSignalUnavailableReason: String
    package let rootSeed: UInt64
    package let startingPhraseIndex: Int
    package let startingBar: Int
    package let nextExpectedPhraseIndex: Int
    package let nextExpectedBar: Int
    package let observedPhraseCount: Int
    package let observedBarCount: Int
    package let segmentBarCount: Int
    package let maximumBarCount: Int
    package let segments: [LongHorizonSessionSegmentEvidence]
    package let payoffMarkerBars: [Int]
    package let recoveryMarkerBars: [Int]
    package let payoffSpacing: LongHorizonSessionSpacingEvidence
    package let payoffRecovery: [LongHorizonSessionPayoffRecoveryEvidence]
    package let capabilityExposure: [LongHorizonSessionCapabilityExposure]
    package let reportFingerprint: String
}

/// Pure bounded analyzer over exact score-owned inputs. It stores no PCM and
/// has no reference to the renderer, evaluator, controller, or transport.
package enum LongHorizonSessionBaselineAnalyzer {
    private struct BarContext {
        let input: LongHorizonSessionBaselineBarInput
        let phraseIndex: Int
        let phraseKind: AutonomousPhraseKind
        let operatorKind: LongHorizonEpisodeOperator?
        let payoffMarker: Bool
        let recoveryMarker: Bool
    }

    package static func analyze(
        _ phrases: [LongHorizonSessionBaselinePhraseInput]
    ) -> LongHorizonSessionBaselineAnalysisResult {
        guard let first = phrases.first else {
            return .unavailable(.noObservations)
        }
        var expectedPhrase = first.phraseIndex
        var expectedBar = first.startBar
        var contexts: [BarContext] = []
        contexts.reserveCapacity(
            LongHorizonSessionBaselineSchema.maximumBarCount
        )
        var hasher = LongHorizonSessionBaselineHasher()
        hasher.combine(LongHorizonSessionBaselineSchema.schemaIdentifier)
        hasher.combine(first.rootSeed)
        hasher.combine(first.phraseIndex)
        hasher.combine(first.startBar)

        for phrase in phrases {
            guard phrase.rootSeed == first.rootSeed else {
                return .unavailable(.rootSeedMismatch)
            }
            guard phrase.phraseIndex == expectedPhrase else {
                return .unavailable(.phraseIndexDiscontinuity)
            }
            guard phrase.startBar == expectedBar else {
                return .unavailable(.barDiscontinuity)
            }
            guard expectedPhrase >= 0 else {
                return .unavailable(.phraseIndexDiscontinuity)
            }
            guard expectedBar >= 0 else {
                return .unavailable(.barDiscontinuity)
            }
            guard !phrase.bars.isEmpty else {
                return .unavailable(.emptyPhrase)
            }
            guard phrase.bars.count <=
                    LongHorizonSemanticTrajectorySchema.maximumPhraseBarCount else {
                return .unavailable(.phraseTooLong)
            }
            guard selectionIsConsistent(phrase) else {
                return .unavailable(.inconsistentSelection)
            }
            guard contexts.count <=
                    LongHorizonSessionBaselineSchema.maximumBarCount -
                    phrase.bars.count else {
                return .unavailable(.barCapacityExceeded)
            }
            guard expectedBar <= Int.max - phrase.bars.count else {
                return .unavailable(.barCapacityExceeded)
            }
            let payoffMarker = phrase.operatorKind == .payoff &&
                phrase.selectionReason == .episodeOperator &&
                phrase.phraseKind == .energyRelease
            let recoveryMarker = phrase.operatorKind == .recover &&
                phrase.selectionReason == .episodeOperator &&
                phrase.phraseKind == .majorBreak
            hasher.combine("phrase")
            hasher.combine(phrase.phraseIndex)
            hasher.combine(phrase.startBar)
            hasher.combine(phrase.phraseKind.rawValue)
            hasher.combine(phrase.operatorKind?.rawValue ?? "none")
            hasher.combine(phrase.selectionReason.rawValue)
            for (index, bar) in phrase.bars.enumerated() {
                guard bar.absoluteBar == expectedBar + index else {
                    return .unavailable(.barDiscontinuity)
                }
                guard scalarsAreValid(bar) else {
                    return .unavailable(.invalidScalar)
                }
                let canonicalCapabilities =
                    LongHorizonSemanticCapability.allCases.filter(
                        bar.capabilities.contains
                    )
                guard canonicalCapabilities == bar.capabilities,
                      Set(bar.capabilities).count == bar.capabilities.count else {
                    return .unavailable(.invalidCapabilityOrder)
                }
                contexts.append(BarContext(
                    input: bar,
                    phraseIndex: phrase.phraseIndex,
                    phraseKind: phrase.phraseKind,
                    operatorKind: phrase.operatorKind,
                    payoffMarker: payoffMarker && index == 0,
                    recoveryMarker: recoveryMarker && index == 0
                ))
                hash(bar, into: &hasher)
            }
            guard expectedPhrase < Int.max else {
                return .unavailable(.phraseIndexDiscontinuity)
            }
            expectedPhrase += 1
            expectedBar += phrase.bars.count
        }

        let segments = stride(
            from: 0,
            to: contexts.count,
            by: LongHorizonSessionBaselineSchema.segmentBarCount
        ).enumerated().map { segmentIndex, offset in
            let end = min(
                contexts.count,
                offset + LongHorizonSessionBaselineSchema.segmentBarCount
            )
            return segment(
                index: segmentIndex,
                contexts: Array(contexts[offset..<end])
            )
        }
        let payoffBars = contexts.filter(\.payoffMarker).map(\.input.absoluteBar)
        let recoveryBars = contexts.filter(\.recoveryMarker).map(\.input.absoluteBar)
        let report = LongHorizonSessionBaselineReport(
            schemaVersion: LongHorizonSessionBaselineSchema.schemaVersion,
            schemaIdentifier: LongHorizonSessionBaselineSchema.schemaIdentifier,
            engineVersion: QualityQualificationContract.engineVersion,
            qualificationStatus: "unavailable",
            qualificationReason:
                LongHorizonSessionBaselineSchema.qualificationReason,
            realizedSignalAvailability: "unavailable",
            realizedSignalUnavailableReason:
                LongHorizonSessionBaselineSchema
                    .realizedSignalUnavailableReason,
            rootSeed: first.rootSeed,
            startingPhraseIndex: first.phraseIndex,
            startingBar: first.startBar,
            nextExpectedPhraseIndex: expectedPhrase,
            nextExpectedBar: expectedBar,
            observedPhraseCount: phrases.count,
            observedBarCount: contexts.count,
            segmentBarCount: LongHorizonSessionBaselineSchema.segmentBarCount,
            maximumBarCount: LongHorizonSessionBaselineSchema.maximumBarCount,
            segments: segments,
            payoffMarkerBars: payoffBars,
            recoveryMarkerBars: recoveryBars,
            payoffSpacing: spacing(payoffBars),
            payoffRecovery: payoffRecovery(
                payoffBars: payoffBars,
                recoveryBars: recoveryBars
            ),
            capabilityExposure: capabilityExposure(contexts),
            reportFingerprint: hasher.fingerprint
        )
        return .available(report)
    }

    private static func selectionIsConsistent(
        _ phrase: LongHorizonSessionBaselinePhraseInput
    ) -> Bool {
        switch phrase.selectionReason {
        case .conservativeFallback:
            return phrase.operatorKind == nil
        case .minimumHold:
            return phrase.operatorKind != nil
        case .reservedPayoff:
            return phrase.operatorKind == .payoff && phrase.phraseKind == .lock
        case .reservedRecall:
            return phrase.operatorKind == .recall && phrase.phraseKind == .lock
        case .payoffDebtEstablishment:
            return phrase.operatorKind == .payoff &&
                phrase.phraseKind == .contrast
        case .episodeOperator:
            guard let operatorKind = phrase.operatorKind else { return false }
            switch operatorKind {
            case .maintain: return phrase.phraseKind == .lock
            case .rise: return phrase.phraseKind == .contrast
            case .recover: return phrase.phraseKind == .majorBreak
            case .reframe:
                return phrase.phraseKind == .contrast ||
                    phrase.phraseKind == .majorBreak
            case .payoff: return phrase.phraseKind == .energyRelease
            case .recall: return phrase.phraseKind == .identityReturn
            }
        }
    }

    private static func scalarsAreValid(
        _ bar: LongHorizonSessionBaselineBarInput
    ) -> Bool {
        bar.absoluteBar >= 0 &&
            [bar.tension, bar.activity, bar.repetition, bar.density]
                .allSatisfy { $0.isFinite && (0...1).contains($0) }
    }

    private static func segment(
        index: Int,
        contexts: [BarContext]
    ) -> LongHorizonSessionSegmentEvidence {
        let bars = contexts.map(\.input)
        let tensions = bars.map(\.tension)
        let signatures = bars.map(\.eventSignature)
        let highFlags = tensions.map {
            $0 >= LongHorizonSessionBaselineSchema.highTensionObservationFloor
        }
        return LongHorizonSessionSegmentEvidence(
            segmentIndex: index,
            startBar: bars[0].absoluteBar,
            endBarExclusive: bars[bars.count - 1].absoluteBar + 1,
            barCount: bars.count,
            complete: bars.count ==
                LongHorizonSessionBaselineSchema.segmentBarCount,
            tension: scalarSummary(tensions),
            activity: scalarSummary(bars.map(\.activity)),
            repetition: scalarSummary(bars.map(\.repetition)),
            density: scalarSummary(bars.map(\.density)),
            highTensionBarCount: highFlags.filter { $0 }.count,
            recoveryTensionBarCount: tensions.filter {
                $0 <= LongHorizonSessionBaselineSchema
                    .recoveryTensionObservationCeiling
            }.count,
            maximumHighTensionRunBars: maximumRun(highFlags),
            payoffMarkerBars: contexts.filter(\.payoffMarker)
                .map(\.input.absoluteBar),
            recoveryMarkerBars: contexts.filter(\.recoveryMarker)
                .map(\.input.absoluteBar),
            repeatedEventSignatureBarCount: repeatedObservationCount(signatures),
            maximumEventSignatureRunBars: maximumEqualRun(signatures),
            phraseKindBarCounts: namedCounts(
                names: AutonomousPhraseKind.allCases.map(\.rawValue),
                values: contexts.map(\.phraseKind.rawValue)
            ),
            operatorBarCounts: namedCounts(
                names: LongHorizonEpisodeOperator.allCases.map(\.rawValue),
                values: contexts.compactMap { $0.operatorKind?.rawValue }
            ),
            sectionBarCounts: namedCounts(
                names: SectionKind.allCases.map(\.rawValue),
                values: bars.map(\.section.rawValue)
            ),
            interlockChapterBarCounts: namedCounts(
                names: InterlockChapter.allCases.map(\.rawValue),
                values: bars.map(\.interlockChapter.rawValue)
            ),
            capabilityExposure: capabilityExposure(contexts)
        )
    }

    private static func scalarSummary(
        _ values: [Double]
    ) -> LongHorizonSessionScalarSummary {
        var maximumStep = 0.0
        var lastDirection = 0
        var directionChanges = 0
        if values.count > 1 {
            for index in 1..<values.count {
                let delta = values[index] - values[index - 1]
                maximumStep = max(maximumStep, abs(delta))
                let direction = delta > 0 ? 1 : (delta < 0 ? -1 : 0)
                if direction != 0 {
                    if lastDirection != 0 && direction != lastDirection {
                        directionChanges += 1
                    }
                    lastDirection = direction
                }
            }
        }
        return LongHorizonSessionScalarSummary(
            observationCount: values.count,
            first: values[0],
            last: values[values.count - 1],
            minimum: values.min()!,
            maximum: values.max()!,
            mean: values.reduce(0, +) / Double(values.count),
            maximumAbsoluteStep: maximumStep,
            directionChangeCount: directionChanges
        )
    }

    private static func namedCounts(
        names: [String],
        values: [String]
    ) -> [LongHorizonSessionNamedBarCount] {
        let counts = Dictionary(grouping: values, by: { $0 })
            .mapValues(\.count)
        return names.map {
            LongHorizonSessionNamedBarCount(
                name: $0,
                barCount: counts[$0, default: 0]
            )
        }
    }

    private static func capabilityExposure(
        _ contexts: [BarContext]
    ) -> [LongHorizonSessionCapabilityExposure] {
        LongHorizonSemanticCapability.allCases.map { capability in
            let flags = contexts.map { $0.input.capabilities.contains(capability) }
            return LongHorizonSessionCapabilityExposure(
                capability: capability,
                activeBarCount: flags.filter { $0 }.count,
                maximumRunBars: maximumRun(flags)
            )
        }
    }

    private static func maximumRun(_ flags: [Bool]) -> Int {
        var current = 0
        var maximum = 0
        for flag in flags {
            current = flag ? current + 1 : 0
            maximum = max(maximum, current)
        }
        return maximum
    }

    private static func maximumEqualRun(_ values: [UInt64]) -> Int {
        guard let first = values.first else { return 0 }
        var prior = first
        var current = 0
        var maximum = 0
        for value in values {
            current = value == prior ? current + 1 : 1
            prior = value
            maximum = max(maximum, current)
        }
        return maximum
    }

    private static func repeatedObservationCount(_ values: [UInt64]) -> Int {
        var seen = Set<UInt64>()
        var repeats = 0
        for value in values {
            if !seen.insert(value).inserted { repeats += 1 }
        }
        return repeats
    }

    private static func spacing(
        _ markers: [Int]
    ) -> LongHorizonSessionSpacingEvidence {
        let intervals = zip(markers, markers.dropFirst()).map { $1 - $0 }
        return LongHorizonSessionSpacingEvidence(
            intervalCount: intervals.count,
            minimumBars: intervals.min(),
            maximumBars: intervals.max(),
            meanBars: intervals.isEmpty ? nil :
                Double(intervals.reduce(0, +)) / Double(intervals.count)
        )
    }

    private static func payoffRecovery(
        payoffBars: [Int],
        recoveryBars: [Int]
    ) -> [LongHorizonSessionPayoffRecoveryEvidence] {
        payoffBars.enumerated().map { index, payoff in
            let nextPayoff = index + 1 < payoffBars.count
                ? payoffBars[index + 1] : nil
            let recovery = recoveryBars.first { recoveryBar in
                recoveryBar > payoff &&
                    (nextPayoff.map { recoveryBar < $0 } ?? true)
            }
            if let recovery {
                return LongHorizonSessionPayoffRecoveryEvidence(
                    payoffBar: payoff,
                    recoveryBar: recovery,
                    latencyBars: recovery - payoff,
                    status: .observed
                )
            }
            return LongHorizonSessionPayoffRecoveryEvidence(
                payoffBar: payoff,
                recoveryBar: nil,
                latencyBars: nil,
                status: .unresolvedWithinHorizon
            )
        }
    }

    private static func hash(
        _ bar: LongHorizonSessionBaselineBarInput,
        into hasher: inout LongHorizonSessionBaselineHasher
    ) {
        hasher.combine("bar")
        hasher.combine(bar.absoluteBar)
        hasher.combine(bar.section.rawValue)
        hasher.combine(bar.interlockChapter.rawValue)
        hasher.combine(bar.tension)
        hasher.combine(bar.activity)
        hasher.combine(bar.repetition)
        hasher.combine(bar.density)
        hasher.combine(bar.eventSignature)
        hasher.combine(bar.capabilities.count)
        for capability in bar.capabilities {
            hasher.combine(capability.rawValue)
        }
    }
}

private struct LongHorizonSessionBaselineHasher {
    private var value: UInt64 = 0xcbf29ce484222325

    mutating func combine(_ string: String) {
        for byte in string.utf8 {
            value ^= UInt64(byte)
            value &*= 0x100000001b3
        }
        value ^= 0xff
        value &*= 0x100000001b3
    }

    mutating func combine(_ integer: Int) {
        combine(UInt64(bitPattern: Int64(integer)))
    }

    mutating func combine(_ integer: UInt64) {
        var little = integer.littleEndian
        withUnsafeBytes(of: &little) { bytes in
            for byte in bytes {
                value ^= UInt64(byte)
                value &*= 0x100000001b3
            }
        }
    }

    mutating func combine(_ scalar: Double) {
        combine(scalar.bitPattern)
    }

    var fingerprint: String { String(format: "%016llx", value) }
}
