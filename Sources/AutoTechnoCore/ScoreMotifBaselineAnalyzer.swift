import Foundation

/// Versioned, detached evidence for score-owned upper-motif recurrence.
/// This analyzer is descriptive only: it owns no planning, rendering,
/// continuation, evaluation, or future-decision state.
package enum ScoreMotifBaselineSchema {
    package static let evidenceVersion = "autotechno-score-motif-baseline.v1"
    package static let analyzerVersion =
        "autotechno-score-motif-baseline-analyzer.v1"
    package static let scoreSchemaVersion =
        "autotechno-resolved-upper-score.v1"
    package static let maximumBarCount = 16
    package static let maximumNotesPerBar = 80
    package static let maximumComparisonLagBars = 4
    package static let gridStepsPerBar = 16
    package static let milliUnitsPerStep = 1_000
    package static let milliUnitsPerSemitone = 1_000
    package static let midiRootC2 = 36
    package static let eligibleRoles: [String] = [
        SynthRole.anchor.rawValue,
        SynthRole.shadow.rawValue,
        SynthRole.response.rawValue,
    ]
    package static let scopeOrder = ["combined"] + eligibleRoles
}

private extension KeyedEncodingContainer {
    mutating func encodeExplicitNull<Value: Encodable>(
        _ value: Value?,
        forKey key: Key
    ) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

package struct ScoreMotifNoteInput: Codable, Equatable, Sendable {
    package let role: String
    package let onsetStep: Int
    package let timingOffsetInSteps: Double
    package let durationInSteps: Double
    package let startFrequencyRatio: Double
    package let endFrequencyRatio: Double
    package let gate: String

    package init(
        role: String,
        onsetStep: Int,
        timingOffsetInSteps: Double = 0,
        durationInSteps: Double,
        startFrequencyRatio: Double,
        endFrequencyRatio: Double? = nil,
        gate: String = UpperNoteGate.retrigger.rawValue
    ) {
        self.role = role
        self.onsetStep = onsetStep
        self.timingOffsetInSteps = timingOffsetInSteps
        self.durationInSteps = durationInSteps
        self.startFrequencyRatio = startFrequencyRatio
        self.endFrequencyRatio = endFrequencyRatio ?? startFrequencyRatio
        self.gate = gate
    }
}

package struct ScoreMotifBarInput: Codable, Equatable, Sendable {
    package let absoluteBar: Int
    package let notes: [ScoreMotifNoteInput]

    package init(absoluteBar: Int, notes: [ScoreMotifNoteInput]) {
        self.absoluteBar = absoluteBar
        self.notes = notes
    }
}

package struct ScoreMotifPhraseInput: Codable, Equatable, Sendable {
    package let phraseIndex: Int
    package let startBar: Int
    package let barCount: Int
    package let tonalCenter: Int
    package let bars: [ScoreMotifBarInput]

    package init(
        phraseIndex: Int,
        startBar: Int,
        barCount: Int,
        tonalCenter: Int,
        bars: [ScoreMotifBarInput]
    ) {
        self.phraseIndex = phraseIndex
        self.startBar = startBar
        self.barCount = barCount
        self.tonalCenter = tonalCenter
        self.bars = bars
    }
}

package enum ScoreMotifBaselineUnavailableReason: String, Codable, Sendable {
    case invalidPhraseBounds = "invalid-phrase-bounds"
    case inconsistentBarIdentity = "inconsistent-bar-identity"
    case tooManyNotes = "too-many-notes"
    case unsupportedRole = "unsupported-role"
    case unsupportedGate = "unsupported-gate"
    case nonFiniteNote = "non-finite-note"
    case noteOutOfBounds = "note-out-of-bounds"
    case inconsistentCanonicalPlan = "inconsistent-canonical-plan"
}

package enum ScoreMotifComparisonAvailability: String, Codable, Sendable {
    case available
    case unavailableNoNotesInEitherBar = "unavailable-no-notes-in-either-bar"
    case unavailableNoNotesInReferenceBar = "unavailable-no-notes-in-reference-bar"
    case unavailableNoNotesInCurrentBar = "unavailable-no-notes-in-current-bar"
}

package struct ScoreMotifToken: Codable, Equatable, Sendable {
    package let ordinal: Int
    package let role: String
    package let onsetMilliSteps: Int
    package let durationMilliSteps: Int
    package let startMIDIMilliNote: Int
    package let endMIDIMilliNote: Int
    package let startPitchClassMilliSemitones: Int
    package let endPitchClassMilliSemitones: Int
    package let gate: String
}

package struct ScoreMotifBarEvidence: Codable, Equatable, Sendable {
    package let phraseBarIndex: Int
    package let absoluteBar: Int
    package let scope: String
    package let active: Bool
    package let noteCount: Int
    package let density: Double
    package let minimumRegisterMIDIMilliNote: Int?
    package let meanRegisterMIDIMilliNote: Double?
    package let maximumRegisterMIDIMilliNote: Int?
    package let exactTokenFingerprint: String?
    package let intervalContourFingerprint: String?
    package let normalizedMotifFingerprint: String?
    package let tokens: [ScoreMotifToken]

    private enum CodingKeys: String, CodingKey {
        case phraseBarIndex
        case absoluteBar
        case scope
        case active
        case noteCount
        case density
        case minimumRegisterMIDIMilliNote
        case meanRegisterMIDIMilliNote
        case maximumRegisterMIDIMilliNote
        case exactTokenFingerprint
        case intervalContourFingerprint
        case normalizedMotifFingerprint
        case tokens
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phraseBarIndex, forKey: .phraseBarIndex)
        try container.encode(absoluteBar, forKey: .absoluteBar)
        try container.encode(scope, forKey: .scope)
        try container.encode(active, forKey: .active)
        try container.encode(noteCount, forKey: .noteCount)
        try container.encode(density, forKey: .density)
        try container.encodeExplicitNull(
            minimumRegisterMIDIMilliNote,
            forKey: .minimumRegisterMIDIMilliNote
        )
        try container.encodeExplicitNull(
            meanRegisterMIDIMilliNote,
            forKey: .meanRegisterMIDIMilliNote
        )
        try container.encodeExplicitNull(
            maximumRegisterMIDIMilliNote,
            forKey: .maximumRegisterMIDIMilliNote
        )
        try container.encodeExplicitNull(
            exactTokenFingerprint,
            forKey: .exactTokenFingerprint
        )
        try container.encodeExplicitNull(
            intervalContourFingerprint,
            forKey: .intervalContourFingerprint
        )
        try container.encodeExplicitNull(
            normalizedMotifFingerprint,
            forKey: .normalizedMotifFingerprint
        )
        try container.encode(tokens, forKey: .tokens)
    }
}

package struct ScoreMotifBarComparison: Codable, Equatable, Sendable {
    package let scope: String
    package let referencePhraseBarIndex: Int
    package let currentPhraseBarIndex: Int
    package let lagBars: Int
    package let availability: ScoreMotifComparisonAvailability
    package let exactRecurrence: Bool?
    package let onsetRecurrence: Bool?
    package let intervalContourRecurrence: Bool?
    package let normalizedMotifRecurrence: Bool?
    package let transpositionMilliSemitones: Int?
    package let noteMutationDistance: Double?
    package let onsetMutationDistance: Double?
    package let durationMutationDistance: Double?
    package let absolutePitchMutationDistance: Double?
    package let pitchClassMutationDistance: Double?
    package let intervalMutationDistance: Double?
    package let roleMutationDistance: Double?
    package let bestReferenceForwardRotationSteps: Int?
    package let rotationNormalizedOnsetMutationDistance: Double?
    package let noteCountDelta: Int?
    package let densityDelta: Double?
    package let meanRegisterShiftMIDIMilliNotes: Double?

    private enum CodingKeys: String, CodingKey {
        case scope
        case referencePhraseBarIndex
        case currentPhraseBarIndex
        case lagBars
        case availability
        case exactRecurrence
        case onsetRecurrence
        case intervalContourRecurrence
        case normalizedMotifRecurrence
        case transpositionMilliSemitones
        case noteMutationDistance
        case onsetMutationDistance
        case durationMutationDistance
        case absolutePitchMutationDistance
        case pitchClassMutationDistance
        case intervalMutationDistance
        case roleMutationDistance
        case bestReferenceForwardRotationSteps
        case rotationNormalizedOnsetMutationDistance
        case noteCountDelta
        case densityDelta
        case meanRegisterShiftMIDIMilliNotes
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scope, forKey: .scope)
        try container.encode(referencePhraseBarIndex, forKey: .referencePhraseBarIndex)
        try container.encode(currentPhraseBarIndex, forKey: .currentPhraseBarIndex)
        try container.encode(lagBars, forKey: .lagBars)
        try container.encode(availability, forKey: .availability)
        try container.encodeExplicitNull(exactRecurrence, forKey: .exactRecurrence)
        try container.encodeExplicitNull(onsetRecurrence, forKey: .onsetRecurrence)
        try container.encodeExplicitNull(
            intervalContourRecurrence,
            forKey: .intervalContourRecurrence
        )
        try container.encodeExplicitNull(
            normalizedMotifRecurrence,
            forKey: .normalizedMotifRecurrence
        )
        try container.encodeExplicitNull(
            transpositionMilliSemitones,
            forKey: .transpositionMilliSemitones
        )
        try container.encodeExplicitNull(
            noteMutationDistance,
            forKey: .noteMutationDistance
        )
        try container.encodeExplicitNull(
            onsetMutationDistance,
            forKey: .onsetMutationDistance
        )
        try container.encodeExplicitNull(
            durationMutationDistance,
            forKey: .durationMutationDistance
        )
        try container.encodeExplicitNull(
            absolutePitchMutationDistance,
            forKey: .absolutePitchMutationDistance
        )
        try container.encodeExplicitNull(
            pitchClassMutationDistance,
            forKey: .pitchClassMutationDistance
        )
        try container.encodeExplicitNull(
            intervalMutationDistance,
            forKey: .intervalMutationDistance
        )
        try container.encodeExplicitNull(
            roleMutationDistance,
            forKey: .roleMutationDistance
        )
        try container.encodeExplicitNull(
            bestReferenceForwardRotationSteps,
            forKey: .bestReferenceForwardRotationSteps
        )
        try container.encodeExplicitNull(
            rotationNormalizedOnsetMutationDistance,
            forKey: .rotationNormalizedOnsetMutationDistance
        )
        try container.encodeExplicitNull(noteCountDelta, forKey: .noteCountDelta)
        try container.encodeExplicitNull(densityDelta, forKey: .densityDelta)
        try container.encodeExplicitNull(
            meanRegisterShiftMIDIMilliNotes,
            forKey: .meanRegisterShiftMIDIMilliNotes
        )
    }
}

package struct ScoreMotifNamedCount: Codable, Equatable, Sendable {
    package let name: String
    package let count: Int
}

package struct ScoreMotifBaselineSummary: Codable, Equatable, Sendable {
    package let barCount: Int
    package let eligibleNoteCount: Int
    package let excludedNoteCounts: [ScoreMotifNamedCount]
    package let availableComparisonCount: Int
    package let exactRecurrenceCount: Int
    package let intervalContourRecurrenceCount: Int
    package let normalizedMotifRecurrenceCount: Int
    package let meanNoteMutationDistance: Double?
    package let meanAbsoluteRegisterShiftSemitones: Double?

    private enum CodingKeys: String, CodingKey {
        case barCount
        case eligibleNoteCount
        case excludedNoteCounts
        case availableComparisonCount
        case exactRecurrenceCount
        case intervalContourRecurrenceCount
        case normalizedMotifRecurrenceCount
        case meanNoteMutationDistance
        case meanAbsoluteRegisterShiftSemitones
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(barCount, forKey: .barCount)
        try container.encode(eligibleNoteCount, forKey: .eligibleNoteCount)
        try container.encode(excludedNoteCounts, forKey: .excludedNoteCounts)
        try container.encode(
            availableComparisonCount,
            forKey: .availableComparisonCount
        )
        try container.encode(exactRecurrenceCount, forKey: .exactRecurrenceCount)
        try container.encode(
            intervalContourRecurrenceCount,
            forKey: .intervalContourRecurrenceCount
        )
        try container.encode(
            normalizedMotifRecurrenceCount,
            forKey: .normalizedMotifRecurrenceCount
        )
        try container.encodeExplicitNull(
            meanNoteMutationDistance,
            forKey: .meanNoteMutationDistance
        )
        try container.encodeExplicitNull(
            meanAbsoluteRegisterShiftSemitones,
            forKey: .meanAbsoluteRegisterShiftSemitones
        )
    }
}

package struct ScoreMotifBaselineEvidence: Codable, Equatable, Sendable {
    package let schema: String
    package let analyzerVersion: String
    package let scoreSchemaVersion: String
    package let phraseIndex: Int
    package let startBar: Int
    package let barCount: Int
    package let tonalCenter: Int
    package let eligibleRoles: [String]
    package let scopeOrder: [String]
    package let bars: [ScoreMotifBarEvidence]
    package let comparisons: [ScoreMotifBarComparison]
    package let summary: ScoreMotifBaselineSummary
    package let evidenceFingerprint: String
}

package enum ScoreMotifBaselineAnalysisResult: Equatable, Sendable {
    case available(ScoreMotifBaselineEvidence)
    case unavailable(ScoreMotifBaselineUnavailableReason)
}

package enum ScoreMotifBaselineAnalyzer {
    package static func canonicalInput(
        plan: AutonomousPhrasePlan
    ) -> ScoreMotifPhraseInput? {
        guard plan.barCount > 0,
              plan.barCount <= ScoreMotifBaselineSchema.maximumBarCount,
              plan.resolvedBars.count == plan.barCount,
              plan.phraseComposition.count == plan.barCount else { return nil }
        let synth = SynthPerformancePlan(
            scene: plan.scene,
            dna: plan.dna,
            kind: plan.kind,
            resolvedBars: plan.resolvedBars,
            materialWorld: plan.materialWorld,
            compositionBars: plan.phraseComposition
        )
        guard synth.bars.count == plan.barCount else { return nil }
        return ScoreMotifPhraseInput(
            phraseIndex: plan.phraseIndex,
            startBar: plan.startBar,
            barCount: plan.barCount,
            tonalCenter: plan.dna.tonalCenter,
            bars: synth.bars.map { bar in
                ScoreMotifBarInput(
                    absoluteBar: bar.bar,
                    notes: bar.upperNotes.map { note in
                        ScoreMotifNoteInput(
                            role: note.role.rawValue,
                            onsetStep: note.onsetStep,
                            timingOffsetInSteps: note.timingOffsetInSteps,
                            durationInSteps: note.durationInSteps,
                            startFrequencyRatio: note.startFrequencyRatio,
                            endFrequencyRatio: note.endFrequencyRatio,
                            gate: note.gate.rawValue
                        )
                    }
                )
            }
        )
    }

    package static func analyze(
        plan: AutonomousPhrasePlan
    ) -> ScoreMotifBaselineAnalysisResult {
        guard let input = canonicalInput(plan: plan) else {
            return .unavailable(.inconsistentCanonicalPlan)
        }
        return analyze(input: input)
    }

    package static func analyze(
        input: ScoreMotifPhraseInput
    ) -> ScoreMotifBaselineAnalysisResult {
        if let reason = validate(input) { return .unavailable(reason) }
        let converted = input.bars.map { bar in
            bar.notes.enumerated().map { index, note in
                token(note, sourceIndex: index, tonalCenter: input.tonalCenter)
            }
        }
        var bars: [ScoreMotifBarEvidence] = []
        bars.reserveCapacity(input.barCount * ScoreMotifBaselineSchema.scopeOrder.count)
        for index in input.bars.indices {
            for scope in ScoreMotifBaselineSchema.scopeOrder {
                let scoped = converted[index]
                    .filter { scope == "combined" || $0.role == scope }
                    .filter { ScoreMotifBaselineSchema.eligibleRoles.contains($0.role) }
                bars.append(barEvidence(
                    phraseBarIndex: index,
                    absoluteBar: input.bars[index].absoluteBar,
                    scope: scope,
                    tokens: scoped
                ))
            }
        }
        var comparisons: [ScoreMotifBarComparison] = []
        for current in 0..<input.barCount {
            for scope in ScoreMotifBaselineSchema.scopeOrder {
                let currentBar = bars.first {
                    $0.phraseBarIndex == current && $0.scope == scope
                }!
                for lag in 1...ScoreMotifBaselineSchema.maximumComparisonLagBars
                    where current >= lag {
                    let referenceBar = bars.first {
                        $0.phraseBarIndex == current - lag && $0.scope == scope
                    }!
                    comparisons.append(comparison(
                        reference: referenceBar,
                        current: currentBar,
                        lag: lag
                    ))
                }
            }
        }
        let available = comparisons.filter { $0.availability == .available }
        let excluded = SynthRole.allCases
            .map(\.rawValue)
            .filter { !ScoreMotifBaselineSchema.eligibleRoles.contains($0) }
            .map { role in
                ScoreMotifNamedCount(
                    name: role,
                    count: converted.flatMap { $0 }.filter { $0.role == role }.count
                )
            }
        let distances = available.compactMap(\.noteMutationDistance)
        let registerShifts = available.compactMap(\.meanRegisterShiftMIDIMilliNotes)
        let summary = ScoreMotifBaselineSummary(
            barCount: input.barCount,
            eligibleNoteCount: converted.flatMap { $0 }.filter {
                ScoreMotifBaselineSchema.eligibleRoles.contains($0.role)
            }.count,
            excludedNoteCounts: excluded,
            availableComparisonCount: available.count,
            exactRecurrenceCount: available.filter { $0.exactRecurrence == true }.count,
            intervalContourRecurrenceCount: available.filter {
                $0.intervalContourRecurrence == true
            }.count,
            normalizedMotifRecurrenceCount: available.filter {
                $0.normalizedMotifRecurrence == true
            }.count,
            meanNoteMutationDistance: mean(distances),
            meanAbsoluteRegisterShiftSemitones: mean(
                registerShifts.map { abs($0) / 1_000 }
            )
        )
        let fingerprint = evidenceFingerprint(
            input: input,
            bars: bars,
            comparisons: comparisons,
            summary: summary
        )
        return .available(ScoreMotifBaselineEvidence(
            schema: ScoreMotifBaselineSchema.evidenceVersion,
            analyzerVersion: ScoreMotifBaselineSchema.analyzerVersion,
            scoreSchemaVersion: ScoreMotifBaselineSchema.scoreSchemaVersion,
            phraseIndex: input.phraseIndex,
            startBar: input.startBar,
            barCount: input.barCount,
            tonalCenter: input.tonalCenter,
            eligibleRoles: ScoreMotifBaselineSchema.eligibleRoles,
            scopeOrder: ScoreMotifBaselineSchema.scopeOrder,
            bars: bars,
            comparisons: comparisons,
            summary: summary,
            evidenceFingerprint: fingerprint
        ))
    }

    private static func validate(
        _ input: ScoreMotifPhraseInput
    ) -> ScoreMotifBaselineUnavailableReason? {
        guard input.phraseIndex >= 0,
              input.startBar >= 0,
              input.barCount > 0,
              input.barCount <= ScoreMotifBaselineSchema.maximumBarCount,
              input.bars.count == input.barCount,
              (0..<12).contains(input.tonalCenter) else {
            return .invalidPhraseBounds
        }
        for (index, bar) in input.bars.enumerated() {
            guard bar.absoluteBar == input.startBar + index else {
                return .inconsistentBarIdentity
            }
            guard bar.notes.count <= ScoreMotifBaselineSchema.maximumNotesPerBar else {
                return .tooManyNotes
            }
            for note in bar.notes {
                guard SynthRole.allCases.map(\.rawValue).contains(note.role) else {
                    return .unsupportedRole
                }
                guard UpperNoteGate.allCases.map(\.rawValue).contains(note.gate) else {
                    return .unsupportedGate
                }
                guard note.timingOffsetInSteps.isFinite,
                      note.durationInSteps.isFinite,
                      note.startFrequencyRatio.isFinite,
                      note.endFrequencyRatio.isFinite else {
                    return .nonFiniteNote
                }
                guard (0..<ScoreMotifBaselineSchema.gridStepsPerBar)
                        .contains(note.onsetStep),
                      (0...ResolvedUpperNote.maximumTimingOffsetInSteps)
                        .contains(note.timingOffsetInSteps),
                      note.durationInSteps >=
                        ResolvedUpperNote.minimumDurationInSteps,
                      note.durationInSteps <=
                        ResolvedUpperNote.maximumDurationInSteps,
                      note.startFrequencyRatio >=
                        ResolvedUpperNote.minimumFrequencyRatio,
                      note.startFrequencyRatio <=
                        ResolvedUpperNote.maximumFrequencyRatio,
                      note.endFrequencyRatio >=
                        ResolvedUpperNote.minimumFrequencyRatio,
                      note.endFrequencyRatio <=
                        ResolvedUpperNote.maximumFrequencyRatio else {
                    return .noteOutOfBounds
                }
            }
        }
        return nil
    }

    private static func token(
        _ note: ScoreMotifNoteInput,
        sourceIndex: Int,
        tonalCenter: Int
    ) -> ScoreMotifToken {
        let start = midiMilliNote(
            ratio: note.startFrequencyRatio,
            tonalCenter: tonalCenter
        )
        let end = midiMilliNote(
            ratio: note.endFrequencyRatio,
            tonalCenter: tonalCenter
        )
        return ScoreMotifToken(
            ordinal: sourceIndex,
            role: note.role,
            onsetMilliSteps: Int((
                Double(note.onsetStep) + note.timingOffsetInSteps
            ) * 1_000.0 + 0.5),
            durationMilliSteps: Int((note.durationInSteps * 1_000).rounded()),
            startMIDIMilliNote: start,
            endMIDIMilliNote: end,
            startPitchClassMilliSemitones: positiveModulo(start, 12_000),
            endPitchClassMilliSemitones: positiveModulo(end, 12_000),
            gate: note.gate
        )
    }

    private static func midiMilliNote(ratio: Double, tonalCenter: Int) -> Int {
        let relative = Int((12 * log2(ratio) * 1_000).rounded())
        return (ScoreMotifBaselineSchema.midiRootC2 + tonalCenter) * 1_000 + relative
    }

    private static func ordered(_ tokens: [ScoreMotifToken]) -> [ScoreMotifToken] {
        tokens.sorted {
            if $0.onsetMilliSteps != $1.onsetMilliSteps {
                return $0.onsetMilliSteps < $1.onsetMilliSteps
            }
            let lhsRole = SynthRole.allCases.map(\.rawValue).firstIndex(of: $0.role) ?? 0
            let rhsRole = SynthRole.allCases.map(\.rawValue).firstIndex(of: $1.role) ?? 0
            if lhsRole != rhsRole { return lhsRole < rhsRole }
            if $0.endMIDIMilliNote != $1.endMIDIMilliNote {
                return $0.endMIDIMilliNote < $1.endMIDIMilliNote
            }
            if $0.durationMilliSteps != $1.durationMilliSteps {
                return $0.durationMilliSteps < $1.durationMilliSteps
            }
            return $0.ordinal < $1.ordinal
        }.enumerated().map { ordinal, token in
            ScoreMotifToken(
                ordinal: ordinal,
                role: token.role,
                onsetMilliSteps: token.onsetMilliSteps,
                durationMilliSteps: token.durationMilliSteps,
                startMIDIMilliNote: token.startMIDIMilliNote,
                endMIDIMilliNote: token.endMIDIMilliNote,
                startPitchClassMilliSemitones: token.startPitchClassMilliSemitones,
                endPitchClassMilliSemitones: token.endPitchClassMilliSemitones,
                gate: token.gate
            )
        }
    }

    private static func barEvidence(
        phraseBarIndex: Int,
        absoluteBar: Int,
        scope: String,
        tokens: [ScoreMotifToken]
    ) -> ScoreMotifBarEvidence {
        let values = ordered(tokens)
        let registers = values.map(\.endMIDIMilliNote)
        let intervals = intervalVector(values)
        let normalized = values.isEmpty ? [] : values.map {
            "\($0.role):\($0.onsetMilliSteps):\($0.durationMilliSteps):" +
                "\($0.startMIDIMilliNote - values[0].endMIDIMilliNote):" +
                "\($0.endMIDIMilliNote - values[0].endMIDIMilliNote):\($0.gate)"
        }
        return ScoreMotifBarEvidence(
            phraseBarIndex: phraseBarIndex,
            absoluteBar: absoluteBar,
            scope: scope,
            active: !values.isEmpty,
            noteCount: values.count,
            density: Double(values.count) / Double(
                ScoreMotifBaselineSchema.gridStepsPerBar *
                    (scope == "combined"
                        ? ScoreMotifBaselineSchema.eligibleRoles.count : 1)
            ),
            minimumRegisterMIDIMilliNote: registers.min(),
            meanRegisterMIDIMilliNote: mean(registers.map(Double.init)),
            maximumRegisterMIDIMilliNote: registers.max(),
            exactTokenFingerprint: values.isEmpty ? nil : fingerprint(
                values.map(exactTokenKey)
            ),
            intervalContourFingerprint: intervals.isEmpty ? nil : fingerprint(
                intervals.map(String.init)
            ),
            normalizedMotifFingerprint: values.isEmpty ? nil : fingerprint(normalized),
            tokens: values
        )
    }

    private static func comparison(
        reference: ScoreMotifBarEvidence,
        current: ScoreMotifBarEvidence,
        lag: Int
    ) -> ScoreMotifBarComparison {
        let availability: ScoreMotifComparisonAvailability
        if reference.tokens.isEmpty && current.tokens.isEmpty {
            availability = .unavailableNoNotesInEitherBar
        } else if reference.tokens.isEmpty {
            availability = .unavailableNoNotesInReferenceBar
        } else if current.tokens.isEmpty {
            availability = .unavailableNoNotesInCurrentBar
        } else {
            availability = .available
        }
        guard availability == .available else {
            return ScoreMotifBarComparison(
                scope: current.scope,
                referencePhraseBarIndex: reference.phraseBarIndex,
                currentPhraseBarIndex: current.phraseBarIndex,
                lagBars: lag,
                availability: availability,
                exactRecurrence: nil,
                onsetRecurrence: nil,
                intervalContourRecurrence: nil,
                normalizedMotifRecurrence: nil,
                transpositionMilliSemitones: nil,
                noteMutationDistance: nil,
                onsetMutationDistance: nil,
                durationMutationDistance: nil,
                absolutePitchMutationDistance: nil,
                pitchClassMutationDistance: nil,
                intervalMutationDistance: nil,
                roleMutationDistance: nil,
                bestReferenceForwardRotationSteps: nil,
                rotationNormalizedOnsetMutationDistance: nil,
                noteCountDelta: nil,
                densityDelta: nil,
                meanRegisterShiftMIDIMilliNotes: nil
            )
        }
        let lhs = reference.tokens
        let rhs = current.tokens
        let lhsIntervals = intervalVector(lhs)
        let rhsIntervals = intervalVector(rhs)
        let contourAvailable = !lhsIntervals.isEmpty && !rhsIntervals.isEmpty
        let contourMatch = contourAvailable ? lhsIntervals == rhsIntervals : nil
        let transposition = lhs.count == rhs.count && contourMatch == true
            ? rhs[0].endMIDIMilliNote - lhs[0].endMIDIMilliNote : nil
        let rotation = bestRotation(
            reference: lhs.map(\.onsetMilliSteps),
            current: rhs.map(\.onsetMilliSteps)
        )
        return ScoreMotifBarComparison(
            scope: current.scope,
            referencePhraseBarIndex: reference.phraseBarIndex,
            currentPhraseBarIndex: current.phraseBarIndex,
            lagBars: lag,
            availability: availability,
            exactRecurrence: lhs.map(exactTokenKey) == rhs.map(exactTokenKey),
            onsetRecurrence: lhs.map(\.onsetMilliSteps) == rhs.map(\.onsetMilliSteps),
            intervalContourRecurrence: contourMatch,
            normalizedMotifRecurrence:
                reference.normalizedMotifFingerprint == current.normalizedMotifFingerprint,
            transpositionMilliSemitones: transposition,
            noteMutationDistance: mutationDistance(
                lhs.map(exactTokenKey), rhs.map(exactTokenKey)
            ),
            onsetMutationDistance: mutationDistance(
                lhs.map(\.onsetMilliSteps), rhs.map(\.onsetMilliSteps)
            ),
            durationMutationDistance: mutationDistance(
                lhs.map(\.durationMilliSteps), rhs.map(\.durationMilliSteps)
            ),
            absolutePitchMutationDistance: mutationDistance(
                lhs.map { "\($0.startMIDIMilliNote):\($0.endMIDIMilliNote)" },
                rhs.map { "\($0.startMIDIMilliNote):\($0.endMIDIMilliNote)" }
            ),
            pitchClassMutationDistance: mutationDistance(
                lhs.map { "\($0.startPitchClassMilliSemitones):" +
                    "\($0.endPitchClassMilliSemitones)" },
                rhs.map { "\($0.startPitchClassMilliSemitones):" +
                    "\($0.endPitchClassMilliSemitones)" }
            ),
            intervalMutationDistance: contourAvailable
                ? mutationDistance(lhsIntervals, rhsIntervals) : nil,
            roleMutationDistance: mutationDistance(
                lhs.map(\.role), rhs.map(\.role)
            ),
            bestReferenceForwardRotationSteps: rotation.shift,
            rotationNormalizedOnsetMutationDistance: rotation.distance,
            noteCountDelta: rhs.count - lhs.count,
            densityDelta: current.density - reference.density,
            meanRegisterShiftMIDIMilliNotes:
                current.meanRegisterMIDIMilliNote! - reference.meanRegisterMIDIMilliNote!
        )
    }

    private static func exactTokenKey(_ token: ScoreMotifToken) -> String {
        "\(token.role):\(token.onsetMilliSteps):\(token.durationMilliSteps):" +
            "\(token.startMIDIMilliNote):\(token.endMIDIMilliNote):\(token.gate)"
    }

    private static func intervalVector(_ tokens: [ScoreMotifToken]) -> [Int] {
        guard tokens.count >= 2 else { return [] }
        return zip(tokens, tokens.dropFirst()).map {
            $0.1.endMIDIMilliNote - $0.0.endMIDIMilliNote
        }
    }

    private static func mutationDistance<T: Equatable>(
        _ lhs: [T],
        _ rhs: [T]
    ) -> Double {
        let denominator = max(lhs.count, rhs.count)
        guard denominator > 0 else { return 0 }
        var previous = Array(0...rhs.count)
        for (row, left) in lhs.enumerated() {
            var current = [row + 1]
            current.reserveCapacity(rhs.count + 1)
            for (column, right) in rhs.enumerated() {
                current.append(min(
                    current[column] + 1,
                    previous[column + 1] + 1,
                    previous[column] + (left == right ? 0 : 1)
                ))
            }
            previous = current
        }
        return Double(previous[rhs.count]) / Double(denominator)
    }

    private static func bestRotation(
        reference: [Int],
        current: [Int]
    ) -> (shift: Int, distance: Double) {
        var best = (shift: 0, distance: Double.infinity)
        let bar = ScoreMotifBaselineSchema.gridStepsPerBar * 1_000
        for shift in 0..<ScoreMotifBaselineSchema.gridStepsPerBar {
            let rotated = reference.map {
                positiveModulo($0 + shift * 1_000, bar)
            }.sorted()
            let distance = mutationDistance(rotated, current.sorted())
            if distance < best.distance { best = (shift, distance) }
        }
        return best
    }

    private static func evidenceFingerprint(
        input: ScoreMotifPhraseInput,
        bars: [ScoreMotifBarEvidence],
        comparisons: [ScoreMotifBarComparison],
        summary: ScoreMotifBaselineSummary
    ) -> String {
        var values = [
            ScoreMotifBaselineSchema.evidenceVersion,
            String(input.phraseIndex), String(input.startBar),
            String(input.barCount), String(input.tonalCenter),
        ]
        values += bars.map {
            "\($0.phraseBarIndex):\($0.scope):" +
                ($0.exactTokenFingerprint ?? "inactive")
        }
        values += comparisons.map {
            "\($0.currentPhraseBarIndex):\($0.scope):\($0.lagBars):" +
                "\($0.availability.rawValue):" +
                String($0.noteMutationDistance ?? -1)
        }
        values.append(String(summary.eligibleNoteCount))
        return fingerprint(values)
    }

    private static func fingerprint(_ values: [String]) -> String {
        var hasher = ScoreMotifHasher()
        for value in values { hasher.combine(value) }
        return hasher.hex
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

private struct ScoreMotifHasher {
    private var value: UInt64 = 0xcbf2_9ce4_8422_2325

    var hex: String { String(format: "%016llx", value) }

    mutating func combine(_ string: String) {
        for byte in string.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01b3
        }
        value ^= 0xff
        value = value &* 0x0000_0100_0000_01b3
    }
}
