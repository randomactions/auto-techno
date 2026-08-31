import Foundation

/// Perceptual material coordinates owned by the canonical long-horizon score.
/// They describe one developing world, not a playlist, style selector, or
/// alternate engine.
package enum LongHorizonRhythmLanguage: String, CaseIterable, Codable, Sendable {
    case fourOnFloor = "four-on-floor"
    case brokenGrid = "broken-grid"
    case crossPulse = "cross-pulse"
    case negativeSpace = "negative-space"
}

package enum LongHorizonMotifTreatment: String, CaseIterable, Codable, Sendable {
    case cyclic
    case fragmented
    case callResponse = "call-response"
    case sustained
}

package enum LongHorizonRoleHierarchy: String, CaseIterable, Codable, Sendable {
    case foundationLed = "foundation-led"
    case protagonistLed = "protagonist-led"
    case percussionLed = "percussion-led"
    case atmosphereLed = "atmosphere-led"
}

package enum LongHorizonHarmonicTreatment: String, CaseIterable, Codable, Sendable {
    case concealedModal = "concealed-modal"
    case suspended
    case disclosedModal = "disclosed-modal"
    case modalFriction = "modal-friction"
}

package enum LongHorizonTimbralArchitecture: String, CaseIterable, Codable, Sendable {
    case resonant
    case tonalMotion = "tonal-motion"
    case spectral
    case hybrid
}

/// A normalized destination for the existing generated graph. The target is
/// score intent; AutoTechnoDSP owns its bounded, gradual realization.
package struct EffectWorldTarget: Codable, Equatable, Sendable {
    package let spectralFocus: Double
    package let nonlinearPressure: Double
    package let modulationMotion: Double
    package let echoMemory: Double
    package let spatialDepth: Double

    package static let neutral = EffectWorldTarget(
        spectralFocus: 0.5,
        nonlinearPressure: 0.35,
        modulationMotion: 0.35,
        echoMemory: 0.25,
        spatialDepth: 0.35
    )

    package init(
        spectralFocus: Double,
        nonlinearPressure: Double,
        modulationMotion: Double,
        echoMemory: Double,
        spatialDepth: Double
    ) {
        self.spectralFocus = Self.clamp(spectralFocus)
        self.nonlinearPressure = Self.clamp(nonlinearPressure)
        self.modulationMotion = Self.clamp(modulationMotion)
        self.echoMemory = Self.clamp(echoMemory)
        self.spatialDepth = Self.clamp(spatialDepth)
    }

    package func distance(from other: EffectWorldTarget) -> Double {
        (
            abs(spectralFocus - other.spectralFocus)
                + abs(nonlinearPressure - other.nonlinearPressure)
                + abs(modulationMotion - other.modulationMotion)
                + abs(echoMemory - other.echoMemory)
                + abs(spatialDepth - other.spatialDepth)
        ) / 5
    }

    package func interpolated(
        from source: EffectWorldTarget,
        progress: Double
    ) -> EffectWorldTarget {
        let linear = min(1, max(0, progress.isFinite ? progress : 0))
        let smooth = linear * linear * (3 - 2 * linear)
        func value(_ start: Double, _ end: Double) -> Double {
            start + (end - start) * smooth
        }
        return EffectWorldTarget(
            spectralFocus: value(source.spectralFocus, spectralFocus),
            nonlinearPressure: value(source.nonlinearPressure, nonlinearPressure),
            modulationMotion: value(source.modulationMotion, modulationMotion),
            echoMemory: value(source.echoMemory, echoMemory),
            spatialDepth: value(source.spatialDepth, spatialDepth)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}

package enum LongHorizonMaterialHandoff: String, Codable, Sendable {
    case lineageMorph = "lineage-morph"
    case layeredRise = "layered-rise"
    case subtractiveBreak = "subtractive-break"
    case transformedBridge = "transformed-bridge"
    case terminalRelease = "terminal-release"
    case transformedRecall = "transformed-recall"

    package init(operatorKind: LongHorizonEpisodeOperator) {
        self = switch operatorKind {
        case .maintain: .lineageMorph
        case .rise: .layeredRise
        case .recover: .subtractiveBreak
        case .reframe: .transformedBridge
        case .payoff: .terminalRelease
        case .recall: .transformedRecall
        }
    }
}

package struct LongHorizonMaterialAxes: Codable, Equatable, Sendable {
    package let rhythm: LongHorizonRhythmLanguage
    package let motif: LongHorizonMotifTreatment
    package let roles: LongHorizonRoleHierarchy
    package let harmony: LongHorizonHarmonicTreatment
    package let architecture: LongHorizonTimbralArchitecture
    package let effect: EffectWorldTarget

    package var focusRole: PerformanceRole {
        switch roles {
        case .foundationLed: .foundation
        case .protagonistLed: .motif
        case .percussionLed: .percussion
        case .atmosphereLed: .atmosphere
        }
    }

    package var rhythmRelationship: LongHorizonEnergyRelationship {
        switch rhythm {
        case .fourOnFloor: .hold
        case .brokenGrid: .change
        case .crossPulse: .raise
        case .negativeSpace: .lower
        }
    }

    package var motifRelationship: LongHorizonEnergyRelationship {
        switch motif {
        case .cyclic: .hold
        case .fragmented: .change
        case .callResponse: .raise
        case .sustained: .lower
        }
    }

    package var harmonicRelationship: LongHorizonEnergyRelationship {
        switch harmony {
        case .concealedModal: .lower
        case .suspended: .hold
        case .disclosedModal: .raise
        case .modalFriction: .change
        }
    }

    package func changedAxisCount(from other: LongHorizonMaterialAxes) -> Int {
        var count = 0
        if rhythm != other.rhythm { count += 1 }
        if motif != other.motif { count += 1 }
        if roles != other.roles { count += 1 }
        if harmony != other.harmony { count += 1 }
        if architecture != other.architecture { count += 1 }
        if effect.distance(from: other.effect) >= 0.12 { count += 1 }
        return count
    }

    package func changedStructuralAxisCount(
        from other: LongHorizonMaterialAxes
    ) -> Int {
        [rhythm != other.rhythm, roles != other.roles, architecture != other.architecture]
            .filter { $0 }.count
    }
}

package struct LongHorizonMaterialWorldIntent: Codable, Equatable, Sendable {
    package let id: UInt64
    package let parentID: UInt64?
    package let parentFingerprint: String?
    package let parentAxes: LongHorizonMaterialAxes?
    package let generation: Int
    package let retryOrdinal: Int
    package let handoff: LongHorizonMaterialHandoff
    package let axes: LongHorizonMaterialAxes
    package let polymetricGrammar: LongHorizonPolymetricGrammar
    package let fingerprint: String

    package var isValid: Bool {
        generation >= 0 && (0...3).contains(retryOrdinal) &&
            !fingerprint.isEmpty && polymetricGrammar.isValid &&
            (generation == 0) == (parentID == nil) &&
            (parentID == nil) == (parentFingerprint == nil) &&
            (parentID == nil) == (parentAxes == nil)
    }
}

/// Phrase-local progress inside the current world. Every field is derived from
/// the episode intent, so retries and route recovery cannot invent a new world.
package struct LongHorizonMaterialWorldPlan: Codable, Equatable, Sendable {
    package let worldID: UInt64
    package let worldFingerprint: String
    package let parentFingerprint: String?
    package let generation: Int
    package let handoff: LongHorizonMaterialHandoff
    package let sourceAxes: LongHorizonMaterialAxes
    package let axes: LongHorizonMaterialAxes
    package let polymetricGrammar: LongHorizonPolymetricGrammar
    package let progress: Double

    package static let neutral = LongHorizonMaterialWorldPlan(
        worldID: 0,
        worldFingerprint: "unbound",
        parentFingerprint: nil,
        generation: 0,
        handoff: .lineageMorph,
        sourceAxes: LongHorizonMaterialAxes(
            rhythm: .fourOnFloor,
            motif: .cyclic,
            roles: .foundationLed,
            harmony: .concealedModal,
            architecture: .hybrid,
            effect: .neutral
        ),
        axes: LongHorizonMaterialAxes(
            rhythm: .fourOnFloor,
            motif: .cyclic,
            roles: .foundationLed,
            harmony: .concealedModal,
            architecture: .hybrid,
            effect: .neutral
        ),
        polymetricGrammar: .neutral,
        progress: 0
    )

    package init(
        worldID: UInt64,
        worldFingerprint: String,
        parentFingerprint: String?,
        generation: Int,
        handoff: LongHorizonMaterialHandoff,
        sourceAxes: LongHorizonMaterialAxes,
        axes: LongHorizonMaterialAxes,
        polymetricGrammar: LongHorizonPolymetricGrammar = .neutral,
        progress: Double
    ) {
        self.worldID = worldID
        self.worldFingerprint = worldFingerprint
        self.parentFingerprint = parentFingerprint
        self.generation = max(0, generation)
        self.handoff = handoff
        self.sourceAxes = sourceAxes
        self.axes = axes
        self.polymetricGrammar = polymetricGrammar.isValid
            ? polymetricGrammar : .neutral
        self.progress = min(1, max(0, progress.isFinite ? progress : 0))
    }

    package init(episode: LongHorizonEpisodeIntent, startBar: Int) {
        let duration = max(
            1,
            episode.minimumHoldUntilBar - episode.startedAtBar
        )
        self.init(
            worldID: episode.materialWorld.id,
            worldFingerprint: episode.materialWorld.fingerprint,
            parentFingerprint: episode.materialWorld.parentFingerprint,
            generation: episode.materialWorld.generation,
            handoff: episode.materialWorld.handoff,
            sourceAxes: episode.materialWorld.parentAxes ??
                episode.materialWorld.axes,
            axes: episode.materialWorld.axes,
            polymetricGrammar: episode.materialWorld.polymetricGrammar,
            progress: Double(max(0, startBar - episode.startedAtBar)) / Double(duration)
        )
    }

    package func isConsistent(with episode: LongHorizonEpisodeIntent) -> Bool {
        worldID == episode.materialWorld.id &&
            worldFingerprint == episode.materialWorld.fingerprint &&
            parentFingerprint == episode.materialWorld.parentFingerprint &&
            generation == episode.materialWorld.generation &&
            handoff == episode.materialWorld.handoff &&
            sourceAxes == (episode.materialWorld.parentAxes ??
                episode.materialWorld.axes) &&
            axes == episode.materialWorld.axes &&
            polymetricGrammar == episode.materialWorld.polymetricGrammar
    }

    /// The target world is stable for the episode, while its score-facing
    /// realization stages categorical handoffs and continuously morphs the
    /// effect coordinates. Every child reaches its full target no later than
    /// the four-minute minimum hold boundary.
    package var resolvedAxes: LongHorizonMaterialAxes {
        guard sourceAxes != axes else { return axes }
        let thresholds = handoffThresholds
        func resolved<T>(_ source: T, _ target: T, threshold: Double) -> T {
            progress >= threshold ? target : source
        }
        return LongHorizonMaterialAxes(
            rhythm: resolved(
                sourceAxes.rhythm,
                axes.rhythm,
                threshold: thresholds.rhythm
            ),
            motif: resolved(
                sourceAxes.motif,
                axes.motif,
                threshold: thresholds.motif
            ),
            roles: resolved(
                sourceAxes.roles,
                axes.roles,
                threshold: thresholds.roles
            ),
            harmony: resolved(
                sourceAxes.harmony,
                axes.harmony,
                threshold: thresholds.harmony
            ),
            architecture: resolved(
                sourceAxes.architecture,
                axes.architecture,
                threshold: thresholds.architecture
            ),
            effect: axes.effect.interpolated(
                from: sourceAxes.effect,
                progress: progress
            )
        )
    }

    private var handoffThresholds: (
        rhythm: Double,
        motif: Double,
        roles: Double,
        harmony: Double,
        architecture: Double
    ) {
        switch handoff {
        case .lineageMorph: (0.30, 0.15, 0.60, 0.45, 0.75)
        case .layeredRise: (0.70, 0.35, 0.55, 0.85, 0.20)
        case .subtractiveBreak: (0.30, 0.55, 0.15, 0.70, 0.85)
        case .transformedBridge: (0.50, 0.30, 0.80, 0.15, 0.65)
        case .terminalRelease: (0.15, 0.80, 0.30, 0.65, 0.45)
        case .transformedRecall: (0.65, 0.15, 0.80, 0.30, 0.50)
        }
    }
}

package enum LongHorizonMaterialWorldResolver {
    private static let effectPresets = [
        EffectWorldTarget(spectralFocus: 0.22, nonlinearPressure: 0.68,
                          modulationMotion: 0.18, echoMemory: 0.16, spatialDepth: 0.20),
        EffectWorldTarget(spectralFocus: 0.72, nonlinearPressure: 0.30,
                          modulationMotion: 0.76, echoMemory: 0.22, spatialDepth: 0.48),
        EffectWorldTarget(spectralFocus: 0.38, nonlinearPressure: 0.18,
                          modulationMotion: 0.30, echoMemory: 0.72, spatialDepth: 0.82),
        EffectWorldTarget(spectralFocus: 0.84, nonlinearPressure: 0.58,
                          modulationMotion: 0.48, echoMemory: 0.52, spatialDepth: 0.36),
        EffectWorldTarget(spectralFocus: 0.52, nonlinearPressure: 0.42,
                          modulationMotion: 0.88, echoMemory: 0.66, spatialDepth: 0.70),
    ]

    package static func make(
        rootSeed: UInt64,
        episodeID: UInt64,
        operatorKind: LongHorizonEpisodeOperator,
        parent: LongHorizonMaterialWorldIntent?,
        recallSource: LongHorizonMaterialWorldIntent?,
        recentFingerprints: [String],
        activationBar: Int = 0
    ) -> LongHorizonMaterialWorldIntent {
        let source = operatorKind == .recall ? (recallSource ?? parent) : parent
        let generation = (parent?.generation ?? -1) + 1
        for retry in 0...3 {
            let seed = SceneDNA.derivedSeed(
                scene: rootSeed ^ episodeID ^ 0x4D41_5445_5249_414C,
                domain: UInt64(operatorKind.rawValue.utf8.reduce(0) { $0 + UInt64($1) }),
                index: generation * 4 + retry
            )
            let axes = source.map { transformedAxes(from: $0.axes, seed: seed) }
                ?? initialAxes(seed: seed)
            let worldID = episodeID ^ seed
            let grammar = LongHorizonPolymetricGrammarResolver.make(
                worldSeed: worldID,
                activationBar: activationBar
            )
            let fingerprint = fingerprint(axes: axes, grammar: grammar)
            let changesImmediateParent = parent.map {
                axes.changedAxisCount(from: $0.axes) >= 4 &&
                    axes.changedStructuralAxisCount(from: $0.axes) >= 2 &&
                    axes.effect.distance(from: $0.axes.effect) >= 0.12
            } ?? true
            if changesImmediateParent &&
                !recentFingerprints.suffix(4).contains(fingerprint)
            {
                return LongHorizonMaterialWorldIntent(
                    id: worldID,
                    parentID: parent?.id,
                    parentFingerprint: parent?.fingerprint,
                    parentAxes: parent?.axes,
                    generation: generation,
                    retryOrdinal: retry,
                    handoff: LongHorizonMaterialHandoff(operatorKind: operatorKind),
                    axes: axes,
                    polymetricGrammar: grammar,
                    fingerprint: fingerprint
                )
            }
        }

        // The immediate parent occupies one slot in the four-world exclusion
        // window. Four distinct non-parent effect presets therefore guarantee
        // at least one candidate remains, even if all three other recent worlds
        // share the fallback's categorical axes.
        let fallbackSource = parent?.axes ?? source?.axes ?? initialAxes(seed: rootSeed)
        let fallbackSeed = SceneDNA.derivedSeed(
            scene: rootSeed ^ episodeID ^ 0x4641_4C4C_4241_434B,
            domain: UInt64(operatorKind.rawValue.utf8.reduce(0) { $0 + UInt64($1) }),
            index: generation
        )
        let nearestEffect = effectPresets.enumerated().min {
            $0.element.distance(from: fallbackSource.effect) <
                $1.element.distance(from: fallbackSource.effect)
        }?.offset ?? 0
        let alternatives = effectPresets.indices.filter { $0 != nearestEffect }
        let start = Int(fallbackSeed % UInt64(alternatives.count))
        for offset in alternatives.indices {
            let effect = effectPresets[alternatives[(start + offset) % alternatives.count]]
            let axes = fallbackAxes(
                from: fallbackSource,
                seed: fallbackSeed,
                effect: effect
            )
            let worldID = episodeID ^ fallbackSeed
            let grammar = LongHorizonPolymetricGrammarResolver.make(
                worldSeed: worldID,
                activationBar: activationBar
            )
            let fingerprint = fingerprint(axes: axes, grammar: grammar)
            guard !recentFingerprints.suffix(4).contains(fingerprint) else {
                continue
            }
            return LongHorizonMaterialWorldIntent(
                id: worldID,
                parentID: parent?.id,
                parentFingerprint: parent?.fingerprint,
                parentAxes: parent?.axes,
                generation: generation,
                retryOrdinal: 3,
                handoff: LongHorizonMaterialHandoff(operatorKind: operatorKind),
                axes: axes,
                polymetricGrammar: grammar,
                fingerprint: fingerprint
            )
        }
        preconditionFailure("bounded material-world fallback exhausted")
    }

    private static func initialAxes(seed: UInt64) -> LongHorizonMaterialAxes {
        LongHorizonMaterialAxes(
            rhythm: pick(LongHorizonRhythmLanguage.allCases, seed: seed, shift: 0),
            motif: pick(LongHorizonMotifTreatment.allCases, seed: seed, shift: 8),
            roles: pick(LongHorizonRoleHierarchy.allCases, seed: seed, shift: 16),
            harmony: pick(LongHorizonHarmonicTreatment.allCases, seed: seed, shift: 24),
            architecture: pick(LongHorizonTimbralArchitecture.allCases, seed: seed, shift: 32),
            effect: effectPresets[Int((seed >> 40) % UInt64(effectPresets.count))]
        )
    }

    private static func transformedAxes(
        from parent: LongHorizonMaterialAxes,
        seed: UInt64
    ) -> LongHorizonMaterialAxes {
        // Rhythm, role hierarchy, architecture, and effect are mandatory
        // changes. Motif and harmony change independently, yielding four to
        // six changed axes without merely permuting a fixed phrase order.
        LongHorizonMaterialAxes(
            rhythm: advanced(parent.rhythm, seed: seed, shift: 0),
            motif: ((seed >> 9) & 1) == 0
                ? parent.motif : advanced(parent.motif, seed: seed, shift: 12),
            roles: advanced(parent.roles, seed: seed, shift: 18),
            harmony: ((seed >> 27) & 1) == 0
                ? parent.harmony : advanced(parent.harmony, seed: seed, shift: 30),
            architecture: advanced(parent.architecture, seed: seed, shift: 36),
            effect: advancedEffect(parent.effect, seed: seed)
        )
    }

    private static func fallbackAxes(
        from parent: LongHorizonMaterialAxes,
        seed: UInt64,
        effect: EffectWorldTarget
    ) -> LongHorizonMaterialAxes {
        LongHorizonMaterialAxes(
            rhythm: advanced(parent.rhythm, seed: seed, shift: 0),
            motif: parent.motif,
            roles: advanced(parent.roles, seed: seed, shift: 12),
            harmony: parent.harmony,
            architecture: advanced(parent.architecture, seed: seed, shift: 24),
            effect: effect
        )
    }

    private static func advanced<T: CaseIterable & Equatable>(
        _ value: T,
        seed: UInt64,
        shift: UInt64
    ) -> T where T.AllCases: RandomAccessCollection, T.AllCases.Index == Int {
        let values = T.allCases
        let index = values.firstIndex(of: value) ?? 0
        let delta = 1 + Int((seed >> shift) % UInt64(max(1, values.count - 1)))
        return values[(index + delta) % values.count]
    }

    private static func pick<T>(
        _ values: [T],
        seed: UInt64,
        shift: UInt64
    ) -> T {
        values[Int((seed >> shift) % UInt64(values.count))]
    }

    private static func advancedEffect(
        _ value: EffectWorldTarget,
        seed: UInt64
    ) -> EffectWorldTarget {
        let nearest = effectPresets.enumerated().min {
            $0.element.distance(from: value) < $1.element.distance(from: value)
        }?.offset ?? 0
        let delta = 1 + Int((seed >> 44) % UInt64(effectPresets.count - 1))
        return effectPresets[(nearest + delta) % effectPresets.count]
    }

    private static func fingerprint(
        axes: LongHorizonMaterialAxes,
        grammar: LongHorizonPolymetricGrammar
    ) -> String {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        let text = [
            axes.rhythm.rawValue, axes.motif.rawValue, axes.roles.rawValue,
            axes.harmony.rawValue, axes.architecture.rawValue,
            String(format: "%.3f", axes.effect.spectralFocus),
            String(format: "%.3f", axes.effect.nonlinearPressure),
            String(format: "%.3f", axes.effect.modulationMotion),
            String(format: "%.3f", axes.effect.echoMemory),
            String(format: "%.3f", axes.effect.spatialDepth),
            grammar.fingerprint,
            String(grammar.activationBar),
            String(grammar.combinedPeriodInSteps)
        ].joined(separator: "|")
        for byte in text.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01b3
        }
        let raw = String(value, radix: 16)
        return String(repeating: "0", count: max(0, 16 - raw.count)) + raw
    }
}
