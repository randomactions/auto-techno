import Foundation

/// Fixed-capacity contract for the hour-scale continuation carried by the one
/// canonical session state. The geometry is planning context, not a calibrated
/// entertainment threshold or a second arrangement engine.
package enum LongHorizonContinuationSchema {
    package static let schemaVersion = 1
    package static let schemaIdentifier = "autotechno-long-horizon-continuation.v1"
    package static let recentEpisodeCapacity = 8
    package static let recentOperatorCapacity = 6
    package static let identityLandmarkCapacity = 8
    package static let obligationCapacity = 8
    package static let minimumEpisodeMacros = 8
    package static let maximumEpisodeMacros = 32
    package static let minimumArcEpisodes = 3
    package static let maximumArcEpisodes = 6
}

/// Source-derived episode functions. These coordinate the existing phrase
/// vocabulary; they are not modes, playlists, tracks, or user choices.
package enum LongHorizonEpisodeOperator: String, CaseIterable, Codable, Sendable {
    case maintain
    case rise
    case recover
    case reframe
    case payoff
    case recall
}

package enum LongHorizonEnergyRelationship: String, Codable, Sendable {
    case lower
    case hold
    case raise
    case change
    case home
}

/// Interpretable semantic coordinates kept separate rather than collapsed into
/// one opaque energy score. Realized signal coordinates remain DSP-owned.
package struct LongHorizonSemanticEnergyVector: Codable, Equatable, Sendable {
    package let foundationAuthority: Double
    package let roleDensity: Double
    package let percussionActivity: Double
    package let protagonistPresence: Double
    package let harmonicDisclosure: Double
    package let timbralMotionIntent: Double
    package let spatialDistance: Double
    package let transitionExpectation: Double

    package static let neutral = LongHorizonSemanticEnergyVector(
        foundationAuthority: 0,
        roleDensity: 0,
        percussionActivity: 0,
        protagonistPresence: 0,
        harmonicDisclosure: 0,
        timbralMotionIntent: 0,
        spatialDistance: 0,
        transitionExpectation: 0
    )

    package init(
        foundationAuthority: Double,
        roleDensity: Double,
        percussionActivity: Double,
        protagonistPresence: Double,
        harmonicDisclosure: Double,
        timbralMotionIntent: Double,
        spatialDistance: Double,
        transitionExpectation: Double
    ) {
        self.foundationAuthority = Self.clamp(foundationAuthority)
        self.roleDensity = Self.clamp(roleDensity)
        self.percussionActivity = Self.clamp(percussionActivity)
        self.protagonistPresence = Self.clamp(protagonistPresence)
        self.harmonicDisclosure = Self.clamp(harmonicDisclosure)
        self.timbralMotionIntent = Self.clamp(timbralMotionIntent)
        self.spatialDistance = Self.clamp(spatialDistance)
        self.transitionExpectation = Self.clamp(transitionExpectation)
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}

package struct LongHorizonEnergyTarget: Codable, Equatable, Sendable {
    package let foundationAuthority: LongHorizonEnergyRelationship
    package let roleDensity: LongHorizonEnergyRelationship
    package let percussionActivity: LongHorizonEnergyRelationship
    package let protagonistPresence: LongHorizonEnergyRelationship
    package let harmonicDisclosure: LongHorizonEnergyRelationship
    package let timbralMotionIntent: LongHorizonEnergyRelationship
    package let spatialDistance: LongHorizonEnergyRelationship
    package let transitionExpectation: LongHorizonEnergyRelationship
}

package enum LongHorizonEpisodeCompletionReason: String, Codable, Sendable {
    case semanticObligationSatisfied = "semantic-obligation-satisfied"
    case maximumDueBoundaryReached = "maximum-due-boundary-reached"
}

package struct LongHorizonEpisodeIntent: Codable, Equatable, Sendable {
    package let id: UInt64
    package let arcIndex: Int
    package let episodeIndex: Int
    package let operatorKind: LongHorizonEpisodeOperator
    package let startedAtBar: Int
    package let minimumHoldUntilBar: Int
    package let dueByBar: Int
    package let startEnergy: LongHorizonSemanticEnergyVector
    package let target: LongHorizonEnergyTarget
}

package struct LongHorizonCompletedEpisode: Codable, Equatable, Sendable {
    package let id: UInt64
    package let arcIndex: Int
    package let episodeIndex: Int
    package let operatorKind: LongHorizonEpisodeOperator
    package let startedAtBar: Int
    package let completedAtBar: Int
    package let minimumHoldUntilBar: Int
    package let dueByBar: Int
    package let completionReason: LongHorizonEpisodeCompletionReason
}

package struct LongHorizonNamedUseRecency: Codable, Equatable, Sendable {
    package let name: String
    package private(set) var useCount: Int
    package private(set) var lastUsedBar: Int?

    fileprivate mutating func observe(atBar bar: Int) {
        useCount = longHorizonContinuationSaturatingIncrement(useCount)
        lastUsedBar = max(lastUsedBar ?? bar, bar)
    }
}

package struct LongHorizonIdentityLandmarkSummary: Codable, Equatable, Sendable {
    package let scoreFingerprint: UInt64
    package let establishedAtBar: Int
    package var lastRecalledAtBar: Int?
}

package enum LongHorizonObligationKind: String, Codable, Sendable {
    case payoff
    case recovery
    case recall
}

package struct LongHorizonObligation: Codable, Equatable, Sendable {
    package let id: UInt64
    package let kind: LongHorizonObligationKind
    package let openedAtBar: Int
    package let dueByBar: Int
    package let sourceEpisodeID: UInt64
    package let sourceScoreFingerprint: UInt64
}

package struct LongHorizonReserveState: Codable, Equatable, Sendable {
    package var payoffAvailable: Bool
    package var reframeAvailable: Bool
    package var recallAvailable: Bool

    fileprivate static let renewed = LongHorizonReserveState(
        payoffAvailable: true,
        reframeAvailable: true,
        recallAvailable: true
    )

    package var availableCount: Int {
        [payoffAvailable, reframeAvailable, recallAvailable].filter { $0 }.count
    }
}

package enum LongHorizonContinuationUpdateUnavailableReason: String, Codable,
    Sendable
{
    case unboundState = "unbound-state"
    case rootSeedMismatch = "root-seed-mismatch"
    case phraseIndexDiscontinuity = "phrase-index-discontinuity"
    case barDiscontinuity = "bar-discontinuity"
    case counterOverflow = "counter-overflow"
    case inconsistentCanonicalPlan = "inconsistent-canonical-plan"
    case obligationCapacityExceeded = "obligation-capacity-exceeded"
}

package enum LongHorizonContinuationUpdateResult: Equatable, Sendable {
    case accepted(LongHorizonContinuationState)
    case preserved(LongHorizonContinuationUpdateUnavailableReason)
}

/// One compact, renewable hierarchy embedded in `TemporalMusicalMemory`.
/// It observes only committed plans. Phase 2 does not let this value choose,
/// reject, correct, or render a phrase.
package struct LongHorizonContinuationState: Codable, Equatable, Sendable {
    package let schemaVersion: Int
    package let schemaIdentifier: String
    package let isBound: Bool
    package let rootSeed: UInt64
    package let nextExpectedPhraseIndex: Int
    package let nextExpectedBar: Int
    package let arcIndex: Int
    package let arcEpisodeCount: Int
    package let currentEpisode: LongHorizonEpisodeIntent
    package let lastSemanticEnergy: LongHorizonSemanticEnergyVector
    package let recentEpisodes: [LongHorizonCompletedEpisode]
    package let recentOperators: [LongHorizonEpisodeOperator]
    package let capabilityRecency: [LongHorizonNamedUseRecency]
    package let characterRecency: [LongHorizonNamedUseRecency]
    package let harmonicRecency: [LongHorizonNamedUseRecency]
    package let transformationRecency: [LongHorizonNamedUseRecency]
    package let identityLandmarks: [LongHorizonIdentityLandmarkSummary]
    package let obligations: [LongHorizonObligation]
    package let reserve: LongHorizonReserveState
    package let lastTrajectoryEvidenceSchema: String?
    package let lastTrajectoryDecisionReason: String

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case schemaIdentifier
        case isBound
        case rootSeed
        case nextExpectedPhraseIndex
        case nextExpectedBar
        case arcIndex
        case arcEpisodeCount
        case currentEpisode
        case lastSemanticEnergy
        case recentEpisodes
        case recentOperators
        case capabilityRecency
        case characterRecency
        case harmonicRecency
        case transformationRecency
        case identityLandmarks
        case obligations
        case reserve
        case lastTrajectoryEvidenceSchema
        case lastTrajectoryDecisionReason
    }

    package static func unbound(
        startingPhraseIndex: Int = 0,
        startingBar: Int = 0
    ) -> LongHorizonContinuationState {
        LongHorizonContinuationState(
            isBound: false,
            rootSeed: 0,
            nextExpectedPhraseIndex: max(0, startingPhraseIndex),
            nextExpectedBar: max(0, startingBar),
            arcIndex: 0,
            arcEpisodeCount: LongHorizonContinuationSchema.minimumArcEpisodes,
            currentEpisode: placeholderEpisode(startingBar: startingBar),
            lastSemanticEnergy: .neutral,
            recentEpisodes: [],
            recentOperators: [],
            capabilityRecency: namedRecency(
                LongHorizonSemanticCapability.allCases.map(\.rawValue)
            ),
            characterRecency: namedRecency(
                PerformanceCharacter.allCases.map(\.rawValue)
            ),
            harmonicRecency: namedRecency(
                PadHarmonicFunction.allCases.map(\.rawValue)
            ),
            transformationRecency: namedRecency(
                MusicalTransformation.allCases.map(\.rawValue)
            ),
            identityLandmarks: [],
            obligations: [],
            reserve: .renewed,
            lastTrajectoryEvidenceSchema: nil,
            lastTrajectoryDecisionReason: "no-calibrated-long-horizon-policy"
        )
    }

    package static func initial(
        rootSeed: UInt64,
        startingPhraseIndex: Int = 0,
        startingBar: Int = 0
    ) -> LongHorizonContinuationState {
        let start = max(0, startingBar)
        let arcCount = arcEpisodeCount(rootSeed: rootSeed, arcIndex: 0)
        let episode = makeEpisode(
            rootSeed: rootSeed,
            arcIndex: 0,
            episodeIndex: 0,
            operatorKind: .maintain,
            startingBar: start,
            startEnergy: .neutral
        )
        return LongHorizonContinuationState(
            isBound: true,
            rootSeed: rootSeed,
            nextExpectedPhraseIndex: max(0, startingPhraseIndex),
            nextExpectedBar: start,
            arcIndex: 0,
            arcEpisodeCount: arcCount,
            currentEpisode: episode,
            lastSemanticEnergy: .neutral,
            recentEpisodes: [],
            recentOperators: [.maintain],
            capabilityRecency: namedRecency(
                LongHorizonSemanticCapability.allCases.map(\.rawValue)
            ),
            characterRecency: namedRecency(
                PerformanceCharacter.allCases.map(\.rawValue)
            ),
            harmonicRecency: namedRecency(
                PadHarmonicFunction.allCases.map(\.rawValue)
            ),
            transformationRecency: namedRecency(
                MusicalTransformation.allCases.map(\.rawValue)
            ),
            identityLandmarks: [],
            obligations: [],
            reserve: .renewed,
            lastTrajectoryEvidenceSchema: nil,
            lastTrajectoryDecisionReason: "no-calibrated-long-horizon-policy"
        )
    }

    private init(
        isBound: Bool,
        rootSeed: UInt64,
        nextExpectedPhraseIndex: Int,
        nextExpectedBar: Int,
        arcIndex: Int,
        arcEpisodeCount: Int,
        currentEpisode: LongHorizonEpisodeIntent,
        lastSemanticEnergy: LongHorizonSemanticEnergyVector,
        recentEpisodes: [LongHorizonCompletedEpisode],
        recentOperators: [LongHorizonEpisodeOperator],
        capabilityRecency: [LongHorizonNamedUseRecency],
        characterRecency: [LongHorizonNamedUseRecency],
        harmonicRecency: [LongHorizonNamedUseRecency],
        transformationRecency: [LongHorizonNamedUseRecency],
        identityLandmarks: [LongHorizonIdentityLandmarkSummary],
        obligations: [LongHorizonObligation],
        reserve: LongHorizonReserveState,
        lastTrajectoryEvidenceSchema: String?,
        lastTrajectoryDecisionReason: String
    ) {
        schemaVersion = LongHorizonContinuationSchema.schemaVersion
        schemaIdentifier = LongHorizonContinuationSchema.schemaIdentifier
        self.isBound = isBound
        self.rootSeed = rootSeed
        self.nextExpectedPhraseIndex = max(0, nextExpectedPhraseIndex)
        self.nextExpectedBar = max(0, nextExpectedBar)
        self.arcIndex = max(0, arcIndex)
        self.arcEpisodeCount = min(
            LongHorizonContinuationSchema.maximumArcEpisodes,
            max(LongHorizonContinuationSchema.minimumArcEpisodes, arcEpisodeCount)
        )
        self.currentEpisode = currentEpisode
        self.lastSemanticEnergy = lastSemanticEnergy
        self.recentEpisodes = Array(
            recentEpisodes.suffix(
                LongHorizonContinuationSchema.recentEpisodeCapacity
            ))
        self.recentOperators = Array(
            recentOperators.suffix(
                LongHorizonContinuationSchema.recentOperatorCapacity
            ))
        self.capabilityRecency = Self.normalizedRecency(
            capabilityRecency,
            names: LongHorizonSemanticCapability.allCases.map(\.rawValue)
        )
        self.characterRecency = Self.normalizedRecency(
            characterRecency,
            names: PerformanceCharacter.allCases.map(\.rawValue)
        )
        self.harmonicRecency = Self.normalizedRecency(
            harmonicRecency,
            names: PadHarmonicFunction.allCases.map(\.rawValue)
        )
        self.transformationRecency = Self.normalizedRecency(
            transformationRecency,
            names: MusicalTransformation.allCases.map(\.rawValue)
        )
        self.identityLandmarks = Array(
            identityLandmarks.suffix(
                LongHorizonContinuationSchema.identityLandmarkCapacity
            ))
        self.obligations = Array(
            obligations.suffix(
                LongHorizonContinuationSchema.obligationCapacity
            ))
        self.reserve = reserve
        self.lastTrajectoryEvidenceSchema = lastTrajectoryEvidenceSchema
        self.lastTrajectoryDecisionReason = lastTrajectoryDecisionReason
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let decodedIdentifier = try container.decode(
            String.self,
            forKey: .schemaIdentifier
        )
        guard decodedVersion == LongHorizonContinuationSchema.schemaVersion,
            decodedIdentifier == LongHorizonContinuationSchema.schemaIdentifier
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaIdentifier,
                in: container,
                debugDescription: "Unsupported long-horizon continuation schema"
            )
        }
        self.init(
            isBound: try container.decode(Bool.self, forKey: .isBound),
            rootSeed: try container.decode(UInt64.self, forKey: .rootSeed),
            nextExpectedPhraseIndex: try container.decode(
                Int.self,
                forKey: .nextExpectedPhraseIndex
            ),
            nextExpectedBar: try container.decode(Int.self, forKey: .nextExpectedBar),
            arcIndex: try container.decode(Int.self, forKey: .arcIndex),
            arcEpisodeCount: try container.decode(Int.self, forKey: .arcEpisodeCount),
            currentEpisode: try container.decode(
                LongHorizonEpisodeIntent.self,
                forKey: .currentEpisode
            ),
            lastSemanticEnergy: try container.decode(
                LongHorizonSemanticEnergyVector.self,
                forKey: .lastSemanticEnergy
            ),
            recentEpisodes: try container.decode(
                [LongHorizonCompletedEpisode].self,
                forKey: .recentEpisodes
            ),
            recentOperators: try container.decode(
                [LongHorizonEpisodeOperator].self,
                forKey: .recentOperators
            ),
            capabilityRecency: try container.decode(
                [LongHorizonNamedUseRecency].self,
                forKey: .capabilityRecency
            ),
            characterRecency: try container.decode(
                [LongHorizonNamedUseRecency].self,
                forKey: .characterRecency
            ),
            harmonicRecency: try container.decode(
                [LongHorizonNamedUseRecency].self,
                forKey: .harmonicRecency
            ),
            transformationRecency: try container.decode(
                [LongHorizonNamedUseRecency].self,
                forKey: .transformationRecency
            ),
            identityLandmarks: try container.decode(
                [LongHorizonIdentityLandmarkSummary].self,
                forKey: .identityLandmarks
            ),
            obligations: try container.decode(
                [LongHorizonObligation].self,
                forKey: .obligations
            ),
            reserve: try container.decode(
                LongHorizonReserveState.self,
                forKey: .reserve
            ),
            lastTrajectoryEvidenceSchema: try container.decodeIfPresent(
                String.self,
                forKey: .lastTrajectoryEvidenceSchema
            ),
            lastTrajectoryDecisionReason: try container.decode(
                String.self,
                forKey: .lastTrajectoryDecisionReason
            )
        )
    }

    package func applying(
        plan: AutonomousPhrasePlan,
        rootSeed suppliedRootSeed: UInt64
    ) -> LongHorizonContinuationUpdateResult {
        guard isBound else { return .preserved(.unboundState) }
        guard suppliedRootSeed == rootSeed else {
            return .preserved(.rootSeedMismatch)
        }
        guard plan.phraseIndex == nextExpectedPhraseIndex else {
            return .preserved(.phraseIndexDiscontinuity)
        }
        guard plan.startBar == nextExpectedBar else {
            return .preserved(.barDiscontinuity)
        }
        guard plan.barCount > 0 else {
            return .preserved(.inconsistentCanonicalPlan)
        }
        guard plan.startBar <= Int.max - plan.barCount else {
            return .preserved(.counterOverflow)
        }
        guard nextExpectedPhraseIndex < Int.max else {
            return .preserved(.counterOverflow)
        }
        guard plan.barCount <= LongHorizonSemanticTrajectorySchema.maximumPhraseBarCount,
            plan.resolvedBars.count == plan.barCount,
            plan.memoryBars.count == plan.barCount,
            plan.phraseComposition.count == plan.barCount,
            plan.scene.seed == suppliedRootSeed &+ 17,
            plan.dna.sceneSeed == suppliedRootSeed &+ 17,
            plan.scene.bpm == AutonomousSessionDirector.bpm,
            let character = plan.resolvedBars.first?.performanceCharacter,
            plan.resolvedBars.indices.allSatisfy({ index in
                let resolved = plan.resolvedBars[index]
                return resolved.performance.bar == plan.startBar + index
                    && resolved.performance.phrase == plan.phraseIndex
                    && resolved.performance.localBar == index
                    && resolved.performanceCharacter == character
                    && plan.phraseComposition[index].bar == resolved.performance.bar
            })
        else {
            return .preserved(.inconsistentCanonicalPlan)
        }

        let endBar = plan.startBar + plan.barCount
        let energy = Self.semanticEnergy(plan)
        var capabilities = capabilityRecency
        var characters = characterRecency
        var harmonics = harmonicRecency
        var transformations = transformationRecency
        var landmarks = identityLandmarks
        var proposedObligations = obligations
        var proposedReserve = reserve

        Self.observe(name: character.rawValue, atBar: plan.startBar, in: &characters)
        for index in plan.resolvedBars.indices {
            let resolved = plan.resolvedBars[index]
            let composition = plan.phraseComposition[index]
            let bar = resolved.performance.bar
            for capability
                in LongHorizonSemanticTrajectoryAccumulator
                .semanticCapabilities(resolved: resolved, composition: composition)
            {
                Self.observe(name: capability.rawValue, atBar: bar, in: &capabilities)
            }
            for transformation in resolved.performance.transformations {
                Self.observe(name: transformation.rawValue, atBar: bar, in: &transformations)
            }
            if let function = composition.padVoicing?.function {
                Self.observe(name: function.rawValue, atBar: bar, in: &harmonics)
            }
            Self.observeIdentityLandmark(
                plan: plan,
                resolved: resolved,
                landmarks: &landmarks
            )
        }

        let satisfies = Self.plan(plan, satisfies: currentEpisode, landmarks: landmarks)
        let held = endBar >= currentEpisode.minimumHoldUntilBar
        let due = endBar >= currentEpisode.dueByBar
        var nextArcIndex = arcIndex
        var nextArcEpisodeCount = arcEpisodeCount
        var nextEpisode = currentEpisode
        var nextRecentEpisodes = recentEpisodes
        var nextRecentOperators = recentOperators

        if held && (satisfies || due) {
            let reason: LongHorizonEpisodeCompletionReason =
                satisfies
                ? .semanticObligationSatisfied : .maximumDueBoundaryReached
            nextRecentEpisodes.append(
                LongHorizonCompletedEpisode(
                    id: currentEpisode.id,
                    arcIndex: currentEpisode.arcIndex,
                    episodeIndex: currentEpisode.episodeIndex,
                    operatorKind: currentEpisode.operatorKind,
                    startedAtBar: currentEpisode.startedAtBar,
                    completedAtBar: endBar,
                    minimumHoldUntilBar: currentEpisode.minimumHoldUntilBar,
                    dueByBar: currentEpisode.dueByBar,
                    completionReason: reason
                ))
            nextRecentEpisodes = Array(
                nextRecentEpisodes.suffix(
                    LongHorizonContinuationSchema.recentEpisodeCapacity
                ))
            if satisfies {
                Self.resolveObligation(
                    for: currentEpisode.operatorKind,
                    atBar: endBar,
                    obligations: &proposedObligations,
                    landmarks: &landmarks
                )
                guard
                    Self.openConsequentObligation(
                        after: currentEpisode,
                        atBar: endBar,
                        sourceFingerprint: Self.lastScoreFingerprint(plan),
                        obligations: &proposedObligations
                    )
                else {
                    return .preserved(.obligationCapacityExceeded)
                }
            }

            guard currentEpisode.episodeIndex < Int.max else {
                return .preserved(.counterOverflow)
            }
            var nextEpisodeIndex = currentEpisode.episodeIndex + 1
            if nextEpisodeIndex >= arcEpisodeCount {
                guard arcIndex < Int.max else {
                    return .preserved(.counterOverflow)
                }
                nextArcIndex = longHorizonContinuationSaturatingIncrement(arcIndex)
                nextArcEpisodeCount = Self.arcEpisodeCount(
                    rootSeed: rootSeed,
                    arcIndex: nextArcIndex
                )
                nextEpisodeIndex = 0
                proposedReserve = .renewed
            }
            let nextOperator = Self.nextOperator(
                rootSeed: rootSeed,
                arcIndex: nextArcIndex,
                episodeIndex: nextEpisodeIndex,
                arcEpisodeCount: nextArcEpisodeCount,
                prior: currentEpisode.operatorKind,
                recent: nextRecentOperators,
                obligations: proposedObligations,
                landmarks: landmarks,
                reserve: proposedReserve
            )
            Self.consumeReserve(nextOperator, reserve: &proposedReserve)
            nextEpisode = Self.makeEpisode(
                rootSeed: rootSeed,
                arcIndex: nextArcIndex,
                episodeIndex: nextEpisodeIndex,
                operatorKind: nextOperator,
                startingBar: endBar,
                startEnergy: energy
            )
            if !Self.openOperatorObligation(
                for: nextEpisode,
                sourceFingerprint: Self.lastScoreFingerprint(plan),
                obligations: &proposedObligations
            ) {
                return .preserved(.obligationCapacityExceeded)
            }
            nextRecentOperators.append(nextOperator)
            nextRecentOperators = Array(
                nextRecentOperators.suffix(
                    LongHorizonContinuationSchema.recentOperatorCapacity
                ))
        }

        return .accepted(
            LongHorizonContinuationState(
                isBound: true,
                rootSeed: rootSeed,
                nextExpectedPhraseIndex:
                    longHorizonContinuationSaturatingIncrement(nextExpectedPhraseIndex),
                nextExpectedBar: endBar,
                arcIndex: nextArcIndex,
                arcEpisodeCount: nextArcEpisodeCount,
                currentEpisode: nextEpisode,
                lastSemanticEnergy: energy,
                recentEpisodes: nextRecentEpisodes,
                recentOperators: nextRecentOperators,
                capabilityRecency: capabilities,
                characterRecency: characters,
                harmonicRecency: harmonics,
                transformationRecency: transformations,
                identityLandmarks: landmarks,
                obligations: proposedObligations,
                reserve: proposedReserve,
                lastTrajectoryEvidenceSchema: lastTrajectoryEvidenceSchema,
                lastTrajectoryDecisionReason: lastTrajectoryDecisionReason
            ))
    }

    package var fingerprint: String {
        var hasher = LongHorizonContinuationHasher()
        hasher.combine(schemaIdentifier)
        hasher.combine(rootSeed)
        hasher.combine(nextExpectedPhraseIndex)
        hasher.combine(nextExpectedBar)
        hasher.combine(arcIndex)
        hasher.combine(arcEpisodeCount)
        hasher.combine(currentEpisode.id)
        hasher.combine(currentEpisode.operatorKind.rawValue)
        hasher.combine(currentEpisode.startedAtBar)
        hasher.combine(currentEpisode.minimumHoldUntilBar)
        hasher.combine(currentEpisode.dueByBar)
        for episode in recentEpisodes {
            hasher.combine(episode.id)
            hasher.combine(episode.completionReason.rawValue)
        }
        for entry in capabilityRecency {
            hasher.combine(entry.name)
            hasher.combine(entry.useCount)
            hasher.combine(entry.lastUsedBar ?? -1)
        }
        for landmark in identityLandmarks {
            hasher.combine(landmark.scoreFingerprint)
            hasher.combine(landmark.establishedAtBar)
            hasher.combine(landmark.lastRecalledAtBar ?? -1)
        }
        for obligation in obligations {
            hasher.combine(obligation.id)
            hasher.combine(obligation.kind.rawValue)
            hasher.combine(obligation.dueByBar)
        }
        return hasher.fingerprint
    }

    private static func placeholderEpisode(startingBar: Int) -> LongHorizonEpisodeIntent {
        LongHorizonEpisodeIntent(
            id: 0,
            arcIndex: 0,
            episodeIndex: 0,
            operatorKind: .maintain,
            startedAtBar: max(0, startingBar),
            minimumHoldUntilBar: max(0, startingBar),
            dueByBar: max(0, startingBar),
            startEnergy: .neutral,
            target: target(for: .maintain)
        )
    }

    private static func namedRecency(_ names: [String]) -> [LongHorizonNamedUseRecency] {
        names.map { LongHorizonNamedUseRecency(name: $0, useCount: 0, lastUsedBar: nil) }
    }

    private static func normalizedRecency(
        _ entries: [LongHorizonNamedUseRecency],
        names: [String]
    ) -> [LongHorizonNamedUseRecency] {
        names.map { name in
            guard let entry = entries.first(where: { $0.name == name }) else {
                return LongHorizonNamedUseRecency(
                    name: name,
                    useCount: 0,
                    lastUsedBar: nil
                )
            }
            return LongHorizonNamedUseRecency(
                name: name,
                useCount: max(0, entry.useCount),
                lastUsedBar: entry.lastUsedBar.map { max(0, $0) }
            )
        }
    }

    private static func observe(
        name: String,
        atBar bar: Int,
        in entries: inout [LongHorizonNamedUseRecency]
    ) {
        guard let index = entries.firstIndex(where: { $0.name == name }) else { return }
        entries[index].observe(atBar: bar)
    }

    private static func semanticEnergy(
        _ plan: AutonomousPhrasePlan
    ) -> LongHorizonSemanticEnergyVector {
        guard plan.barCount > 0 else { return .neutral }
        var foundation = 0.0
        var roleDensity = 0.0
        var percussion = 0.0
        var protagonist = 0.0
        var disclosure = 0.0
        var motion = 0.0
        var distance = 0.0
        var expectation = 0.0
        for index in plan.resolvedBars.indices {
            let resolved = plan.resolvedBars[index]
            let bar = resolved.performance
            let composition = plan.phraseComposition[index]
            if bar.roles.contains(.foundation), resolved.foundationBehavior != .absent {
                foundation += 1
            }
            roleDensity += Double(bar.roles.count) / Double(PerformanceRole.allCases.count)
            percussion += min(1, Double(resolved.groovePulses.count) / 8)
            protagonist += resolved.narrative.presenceEnd
            if let pad = composition.padVoicing {
                let disclosureValue: Double
                switch pad.harmonicDisclosureStage {
                case .concealed: disclosureValue = 0
                case .partial: disclosureValue = 0.5
                case .revealed, .established: disclosureValue = 1
                }
                disclosure += disclosureValue
            }
            if bar.transformations.contains(where: {
                $0 != .`repeat` && $0 != .restore
            }) {
                motion += 1
            }
            if resolved.spatialContrast.depthPosition == .distant { distance += 1 }
            if bar.roles.contains(.transition) || resolved.percussionEchoTexture != nil
                || resolved.kickSyntaxRole == .withheld
            {
                expectation += 1
            }
        }
        let count = Double(plan.barCount)
        return LongHorizonSemanticEnergyVector(
            foundationAuthority: foundation / count,
            roleDensity: roleDensity / count,
            percussionActivity: percussion / count,
            protagonistPresence: protagonist / count,
            harmonicDisclosure: disclosure / count,
            timbralMotionIntent: motion / count,
            spatialDistance: distance / count,
            transitionExpectation: expectation / count
        )
    }

    private static func observeIdentityLandmark(
        plan: AutonomousPhrasePlan,
        resolved: ResolvedPerformanceBar,
        landmarks: inout [LongHorizonIdentityLandmarkSummary]
    ) {
        let signature = plan.memoryBars[resolved.performance.localBar].eventSignature
        let bar = resolved.performance.bar
        if plan.kind == .lock,
            resolved.performanceCharacter == .hypnoticLock,
            !landmarks.contains(where: { $0.scoreFingerprint == signature })
        {
            landmarks.append(
                LongHorizonIdentityLandmarkSummary(
                    scoreFingerprint: signature,
                    establishedAtBar: bar,
                    lastRecalledAtBar: nil
                ))
            landmarks = Array(
                landmarks.suffix(
                    LongHorizonContinuationSchema.identityLandmarkCapacity
                ))
        } else if plan.kind == .identityReturn,
            let index = landmarks.firstIndex(where: {
                $0.scoreFingerprint == signature
            })
        {
            landmarks[index].lastRecalledAtBar = bar
        }
    }

    private static func plan(
        _ plan: AutonomousPhrasePlan,
        satisfies episode: LongHorizonEpisodeIntent,
        landmarks: [LongHorizonIdentityLandmarkSummary]
    ) -> Bool {
        switch episode.operatorKind {
        case .maintain:
            return plan.kind == .lock
        case .rise:
            return plan.kind == .contrast
        case .recover:
            return plan.kind == .majorBreak
        case .reframe:
            return plan.kind == .contrast || plan.kind == .majorBreak
        case .payoff:
            return plan.kind == .energyRelease && !plan.paidDebtIDs.isEmpty
        case .recall:
            guard plan.kind == .identityReturn else { return false }
            return plan.memoryBars.contains { bar in
                landmarks.contains { $0.scoreFingerprint == bar.eventSignature }
            } || !landmarks.isEmpty
        }
    }

    private static func arcEpisodeCount(rootSeed: UInt64, arcIndex: Int) -> Int {
        let span =
            LongHorizonContinuationSchema.maximumArcEpisodes
            - LongHorizonContinuationSchema.minimumArcEpisodes + 1
        let value = episodeSeed(
            rootSeed: rootSeed,
            arcIndex: arcIndex,
            episodeIndex: 0,
            domain: 0xA2C_C017
        )
        return LongHorizonContinuationSchema.minimumArcEpisodes + Int(value % UInt64(span))
    }

    private static func makeEpisode(
        rootSeed: UInt64,
        arcIndex: Int,
        episodeIndex: Int,
        operatorKind: LongHorizonEpisodeOperator,
        startingBar: Int,
        startEnergy: LongHorizonSemanticEnergyVector
    ) -> LongHorizonEpisodeIntent {
        let seed = episodeSeed(
            rootSeed: rootSeed,
            arcIndex: arcIndex,
            episodeIndex: episodeIndex,
            domain: 0xE915_0DE
        )
        let baseRange: ClosedRange<Int> =
            switch operatorKind {
            case .maintain: 8...16
            case .rise: 9...20
            case .recover: 8...16
            case .reframe: 8...18
            case .payoff: 8...12
            case .recall: 8...16
            }
        let baseSpan = baseRange.upperBound - baseRange.lowerBound + 1
        let minimumMacros = baseRange.lowerBound + Int(seed % UInt64(baseSpan))
        let extraMaximum = max(
            4,
            LongHorizonContinuationSchema.maximumEpisodeMacros - minimumMacros
        )
        let extra = 4 + Int((seed >> 8) % UInt64(extraMaximum - 3))
        let dueMacros = min(
            LongHorizonContinuationSchema.maximumEpisodeMacros,
            minimumMacros + extra
        )
        let start = max(0, startingBar)
        return LongHorizonEpisodeIntent(
            id: episodeSeed(
                rootSeed: rootSeed,
                arcIndex: arcIndex,
                episodeIndex: episodeIndex,
                domain: 0x1D
            ),
            arcIndex: arcIndex,
            episodeIndex: episodeIndex,
            operatorKind: operatorKind,
            startedAtBar: start,
            minimumHoldUntilBar: saturatingAdd(start, minimumMacros * 16),
            dueByBar: saturatingAdd(start, dueMacros * 16),
            startEnergy: startEnergy,
            target: target(for: operatorKind)
        )
    }

    private static func target(
        for operatorKind: LongHorizonEpisodeOperator
    ) -> LongHorizonEnergyTarget {
        switch operatorKind {
        case .maintain:
            return LongHorizonEnergyTarget(
                foundationAuthority: .hold, roleDensity: .hold,
                percussionActivity: .hold, protagonistPresence: .hold,
                harmonicDisclosure: .hold, timbralMotionIntent: .change,
                spatialDistance: .hold, transitionExpectation: .lower
            )
        case .rise:
            return LongHorizonEnergyTarget(
                foundationAuthority: .hold, roleDensity: .raise,
                percussionActivity: .raise, protagonistPresence: .raise,
                harmonicDisclosure: .raise, timbralMotionIntent: .raise,
                spatialDistance: .change, transitionExpectation: .raise
            )
        case .recover:
            return LongHorizonEnergyTarget(
                foundationAuthority: .lower, roleDensity: .lower,
                percussionActivity: .lower, protagonistPresence: .lower,
                harmonicDisclosure: .change, timbralMotionIntent: .lower,
                spatialDistance: .raise, transitionExpectation: .lower
            )
        case .reframe:
            return LongHorizonEnergyTarget(
                foundationAuthority: .hold, roleDensity: .lower,
                percussionActivity: .change, protagonistPresence: .change,
                harmonicDisclosure: .change, timbralMotionIntent: .change,
                spatialDistance: .change, transitionExpectation: .hold
            )
        case .payoff:
            return LongHorizonEnergyTarget(
                foundationAuthority: .raise, roleDensity: .raise,
                percussionActivity: .raise, protagonistPresence: .raise,
                harmonicDisclosure: .raise, timbralMotionIntent: .raise,
                spatialDistance: .lower, transitionExpectation: .lower
            )
        case .recall:
            return LongHorizonEnergyTarget(
                foundationAuthority: .home, roleDensity: .home,
                percussionActivity: .home, protagonistPresence: .home,
                harmonicDisclosure: .home, timbralMotionIntent: .change,
                spatialDistance: .home, transitionExpectation: .lower
            )
        }
    }

    private static func nextOperator(
        rootSeed: UInt64,
        arcIndex: Int,
        episodeIndex: Int,
        arcEpisodeCount: Int,
        prior: LongHorizonEpisodeOperator,
        recent: [LongHorizonEpisodeOperator],
        obligations: [LongHorizonObligation],
        landmarks: [LongHorizonIdentityLandmarkSummary],
        reserve: LongHorizonReserveState
    ) -> LongHorizonEpisodeOperator {
        let outstandingKinds = Set(obligations.map(\.kind))
        if outstandingKinds.contains(.recovery), prior != .recover {
            return .recover
        }
        if outstandingKinds.contains(.payoff), reserve.payoffAvailable,
            episodeIndex >= 1, prior != .payoff
        {
            return .payoff
        }
        if episodeIndex == arcEpisodeCount - 1,
            !landmarks.isEmpty,
            reserve.recallAvailable,
            prior != .recall
        {
            return .recall
        }

        var choices: [LongHorizonEpisodeOperator]
        if episodeIndex == 0 {
            choices = [.maintain, .rise, .reframe]
        } else {
            choices =
                switch prior {
                case .maintain: [.rise, .reframe, .maintain]
                case .rise: [.maintain, .recover, .reframe]
                case .recover: [.maintain, .rise, .reframe]
                case .reframe: [.maintain, .rise, .recover]
                case .payoff: [.recover]
                case .recall: [.maintain, .rise]
                }
        }
        if !reserve.reframeAvailable { choices.removeAll { $0 == .reframe } }
        if landmarks.isEmpty { choices.removeAll { $0 == .recall } }
        let recentSet = Set(recent.suffix(2))
        let unrepeated = choices.filter { !recentSet.contains($0) }
        if !unrepeated.isEmpty { choices = unrepeated }
        if choices.isEmpty { choices = [.maintain] }
        let seed = episodeSeed(
            rootSeed: rootSeed,
            arcIndex: arcIndex,
            episodeIndex: episodeIndex,
            domain: 0x0E2A_702
        )
        return choices[Int(seed % UInt64(choices.count))]
    }

    private static func consumeReserve(
        _ operatorKind: LongHorizonEpisodeOperator,
        reserve: inout LongHorizonReserveState
    ) {
        switch operatorKind {
        case .payoff: reserve.payoffAvailable = false
        case .reframe: reserve.reframeAvailable = false
        case .recall: reserve.recallAvailable = false
        case .maintain, .rise, .recover: break
        }
    }

    private static func openOperatorObligation(
        for episode: LongHorizonEpisodeIntent,
        sourceFingerprint: UInt64,
        obligations: inout [LongHorizonObligation]
    ) -> Bool {
        let kind: LongHorizonObligationKind?
        switch episode.operatorKind {
        case .rise: kind = .payoff
        case .reframe: kind = .recall
        case .maintain, .recover, .payoff, .recall: kind = nil
        }
        guard let kind else { return true }
        guard !obligations.contains(where: { $0.kind == kind }) else { return true }
        guard obligations.count < LongHorizonContinuationSchema.obligationCapacity else {
            return false
        }
        obligations.append(
            LongHorizonObligation(
                id: episode.id ^ UInt64(kind.rawValue.utf8.reduce(0, { $0 + UInt64($1) })),
                kind: kind,
                openedAtBar: episode.startedAtBar,
                dueByBar: saturatingAdd(
                    episode.dueByBar,
                    2 * 16 * LongHorizonContinuationSchema.maximumEpisodeMacros
                ),
                sourceEpisodeID: episode.id,
                sourceScoreFingerprint: sourceFingerprint
            ))
        return true
    }

    private static func openConsequentObligation(
        after episode: LongHorizonEpisodeIntent,
        atBar bar: Int,
        sourceFingerprint: UInt64,
        obligations: inout [LongHorizonObligation]
    ) -> Bool {
        guard episode.operatorKind == .payoff else { return true }
        guard !obligations.contains(where: { $0.kind == .recovery }) else { return true }
        guard obligations.count < LongHorizonContinuationSchema.obligationCapacity else {
            return false
        }
        obligations.append(
            LongHorizonObligation(
                id: episode.id ^ 0x2EC0_0E2,
                kind: .recovery,
                openedAtBar: bar,
                dueByBar: saturatingAdd(
                    bar,
                    2 * 16 * LongHorizonContinuationSchema.maximumEpisodeMacros
                ),
                sourceEpisodeID: episode.id,
                sourceScoreFingerprint: sourceFingerprint
            ))
        return true
    }

    private static func resolveObligation(
        for operatorKind: LongHorizonEpisodeOperator,
        atBar bar: Int,
        obligations: inout [LongHorizonObligation],
        landmarks: inout [LongHorizonIdentityLandmarkSummary]
    ) {
        let kind: LongHorizonObligationKind?
        switch operatorKind {
        case .payoff: kind = .payoff
        case .recover: kind = .recovery
        case .recall: kind = .recall
        case .maintain, .rise, .reframe: kind = nil
        }
        if let kind, let index = obligations.firstIndex(where: { $0.kind == kind }) {
            let source = obligations[index].sourceScoreFingerprint
            obligations.remove(at: index)
            if kind == .recall,
                let landmark = landmarks.firstIndex(where: {
                    $0.scoreFingerprint == source
                })
            {
                landmarks[landmark].lastRecalledAtBar = bar
            }
        }
    }

    private static func lastScoreFingerprint(_ plan: AutonomousPhrasePlan) -> UInt64 {
        plan.memoryBars.last?.eventSignature ?? 0
    }

    private static func saturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
        guard rhs > 0 else { return lhs }
        return lhs > Int.max - rhs ? Int.max : lhs + rhs
    }

    private static func episodeSeed(
        rootSeed: UInt64,
        arcIndex: Int,
        episodeIndex: Int,
        domain: UInt64
    ) -> UInt64 {
        let arcDomain = UInt64(max(0, arcIndex)) + 1
        return SceneDNA.derivedSeed(
            scene: rootSeed ^ domain,
            domain: arcDomain,
            index: max(0, episodeIndex)
        )
    }
}

private struct LongHorizonContinuationHasher {
    private var value: UInt64 = 0xcbf2_9ce4_8422_2325

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

private func longHorizonContinuationSaturatingIncrement(_ value: Int) -> Int {
    value == Int.max ? Int.max : value + 1
}
