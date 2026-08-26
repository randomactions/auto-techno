import AutoTechnoCore
import AutoTechnoDSP
import Foundation

/// A bounded, immutable presentation projection of one already-rendered bar.
/// It contains no PCM and is assembled during detached phrase preparation.
package struct LiveRenderSnapshot: Equatable, Sendable {
    package struct Voice: Equatable, Sendable {
        package let name: String
        package let eventCount: Int
    }

    package struct Assignment: Equatable, Sendable {
        package let identity: String
        package let role: String
        package let architecture: String
        package let patch: String
        package let eventCount: Int
        package let color: Double
        package let shape: Double
        package let motion: Double
        package let space: Double
        package let effects: [String]
    }

    package struct Capability: Equatable, Sendable {
        package let name: String
        package let value: String
    }

    package struct Effect: Equatable, Sendable {
        package let name: String
        package let amount: Double
    }

    package struct GraphNode: Equatable, Sendable {
        package let identity: Int
        package let name: String
        package let branch: Int
        package let amount: Double
        package let mix: Double
        package let feedback: Double
        package let delayMilliseconds: Double
    }

    package struct MixGain: Equatable, Sendable {
        package let role: String
        package let decibels: Double
    }

    package let available: Bool
    package let phraseNumber: Int
    package let barNumber: Int
    package let absoluteBarNumber: Int
    package let phraseBarCount: Int
    package let sampleRate: Double
    package let channelCount: Int
    package let frameCount: Int
    package let durationSeconds: Double

    package let phraseKind: String
    package let section: String
    package let performanceCharacter: String
    package let arrangementGesture: String
    package let interlockChapter: String
    package let foundationBehavior: String
    package let focusRole: String
    package let percussionGear: String
    package let kickSyntax: String
    package let transformations: [String]
    package let signatureEvent: String?

    package let voices: [Voice]
    package let assignments: [Assignment]
    package let capabilities: [Capability]
    package let effects: [Effect]
    package let graphRevision: Int
    package let graphMutation: String
    package let graphBranchCount: Int
    package let graphMaximumDepth: Int
    package let graphNodes: [GraphNode]
    package let mixGains: [MixGain]
    package let measuredKickOverFoundationDB: Double?
    package let targetKickOverFoundationDB: Double?

    package let peak: Double
    package let truePeak: Double
    package let rms: Double
    package let loudnessEstimate: Double
    package let stereoCorrelation: Double
    package let liveMasterTrimDB: Double
    package let qualityOutcome: String
    package let qualityPolicyVersion: String
    package let playbackHardGatesPassed: Bool
    package let usedHomeTimbreCorrection: Bool

    package static let waiting = LiveRenderSnapshot(
        available: false,
        phraseNumber: 1,
        barNumber: 1,
        absoluteBarNumber: 1,
        phraseBarCount: 0,
        sampleRate: 0,
        channelCount: 0,
        frameCount: 0,
        durationSeconds: 0,
        phraseKind: "Waiting",
        section: "Waiting",
        performanceCharacter: "Waiting",
        arrangementGesture: "Waiting",
        interlockChapter: "Waiting",
        foundationBehavior: "Waiting",
        focusRole: "Waiting",
        percussionGear: "Waiting",
        kickSyntax: "Waiting",
        transformations: [],
        signatureEvent: nil,
        voices: [],
        assignments: [],
        capabilities: [],
        effects: [],
        graphRevision: 0,
        graphMutation: "None",
        graphBranchCount: 0,
        graphMaximumDepth: 0,
        graphNodes: [],
        mixGains: [],
        measuredKickOverFoundationDB: nil,
        targetKickOverFoundationDB: nil,
        peak: 0,
        truePeak: 0,
        rms: 0,
        loudnessEstimate: -120,
        stereoCorrelation: 0,
        liveMasterTrimDB: 0,
        qualityOutcome: "Waiting",
        qualityPolicyVersion: "Waiting",
        playbackHardGatesPassed: false,
        usedHomeTimbreCorrection: false
    )

    package static func make(
        prepared: PreparedAutonomousPhrase,
        sampleRate: Double,
        channelCount: Int
    ) -> [LiveRenderSnapshot] {
        make(
            plan: prepared.plan,
            graph: prepared.graph,
            blocks: prepared.blocks,
            sampleRate: sampleRate,
            channelCount: channelCount,
            qualityOutcome: prepared.qualityDecision.outcome.rawValue,
            qualityPolicyVersion: prepared.qualityDecision.policyVersion,
            playbackHardGatesPassed: prepared.playbackHardGatesPassed,
            usedHomeTimbreCorrection: prepared.usedHomeTimbreCorrection
        )
    }

    package static func make(
        plan: AutonomousPhrasePlan,
        graph: DSPGraphPlan,
        blocks: [RenderBlock],
        sampleRate: Double,
        channelCount: Int,
        qualityOutcome: String = "prepared",
        qualityPolicyVersion: String = "unreported",
        playbackHardGatesPassed: Bool = true,
        usedHomeTimbreCorrection: Bool = false
    ) -> [LiveRenderSnapshot] {
        guard sampleRate.isFinite, sampleRate > 0, channelCount > 0 else {
            return []
        }
        return blocks.map { block in
            snapshot(
                plan: plan,
                graph: graph,
                block: block,
                sampleRate: sampleRate,
                channelCount: channelCount,
                qualityOutcome: qualityOutcome,
                qualityPolicyVersion: qualityPolicyVersion,
                playbackHardGatesPassed: playbackHardGatesPassed,
                usedHomeTimbreCorrection: usedHomeTimbreCorrection
            )
        }
    }

    private static func snapshot(
        plan: AutonomousPhrasePlan,
        graph: DSPGraphPlan,
        block: RenderBlock,
        sampleRate: Double,
        channelCount: Int,
        qualityOutcome: String,
        qualityPolicyVersion: String,
        playbackHardGatesPassed: Bool,
        usedHomeTimbreCorrection: Bool
    ) -> LiveRenderSnapshot {
        let performance = block.resolvedPerformance
        let frameCount = min(block.left.count, block.right.count)
        let graphNodes = graph.nodes.map { node in
            GraphNode(
                identity: node.id,
                name: InspectorLabel.title(node.kind.rawValue),
                branch: node.branch + 1,
                amount: node.amount,
                mix: node.mix,
                feedback: node.feedback,
                delayMilliseconds: node.delaySeconds * 1_000
            )
        }
        let activeEffects = block.effects.filter(\.active).map { effect in
            Effect(
                name: InspectorLabel.title(effect.kind.rawValue),
                amount: effect.amount
            )
        }
        let mixGains = MixRole.allCases.map { role in
            MixGain(
                role: InspectorLabel.title(role.rawValue),
                decibels: block.automaticMix.gainsDB[role] ?? 0
            )
        }
        return LiveRenderSnapshot(
            available: true,
            phraseNumber: plan.phraseIndex + 1,
            barNumber: block.performance.localBar + 1,
            absoluteBarNumber: block.bar + 1,
            phraseBarCount: plan.barCount,
            sampleRate: sampleRate,
            channelCount: channelCount,
            frameCount: frameCount,
            durationSeconds: Double(frameCount) / sampleRate,
            phraseKind: InspectorLabel.title(plan.kind.rawValue),
            section: block.section.displayName,
            performanceCharacter: InspectorLabel.title(
                performance.performanceCharacter.rawValue
            ),
            arrangementGesture: InspectorLabel.title(
                performance.arrangementGesture.rawValue
            ),
            interlockChapter: InspectorLabel.title(
                performance.interlockChapter.rawValue
            ),
            foundationBehavior: InspectorLabel.title(
                performance.foundationBehavior.rawValue
            ),
            focusRole: InspectorLabel.title(performance.ensemble.focusRole.rawValue),
            percussionGear: InspectorLabel.title(performance.percussionGear.rawValue),
            kickSyntax: InspectorLabel.title(performance.kickSyntaxRole.rawValue),
            transformations: block.performance.transformations.map {
                InspectorLabel.title($0.rawValue)
            },
            signatureEvent: block.performance.signatureEvent.map {
                InspectorLabel.title($0.rawValue)
            },
            voices: activeVoices(in: block),
            assignments: activeAssignments(in: block),
            capabilities: activeCapabilities(in: block),
            effects: activeEffects,
            graphRevision: graph.revision,
            graphMutation: graph.mutation.map {
                "\(InspectorLabel.title($0.kind.rawValue)) · phrase \($0.phraseIndex + 1)"
            } ?? "None",
            graphBranchCount: graph.branchCount,
            graphMaximumDepth: graph.maximumDepth,
            graphNodes: graphNodes,
            mixGains: mixGains,
            measuredKickOverFoundationDB:
                block.automaticMix.measuredKickOverFoundationDB,
            targetKickOverFoundationDB:
                block.automaticMix.targetKickOverFoundationDB,
            peak: Double(block.peak),
            truePeak: Double(block.truePeakEstimate),
            rms: Double(block.rms),
            loudnessEstimate: Double(block.loudnessEstimate),
            stereoCorrelation: Double(block.stereoCorrelation),
            liveMasterTrimDB:
                block.liveMasterTrimRenderEvidence.appliedTrimDB,
            qualityOutcome: InspectorLabel.title(qualityOutcome),
            qualityPolicyVersion: qualityPolicyVersion,
            playbackHardGatesPassed: playbackHardGatesPassed,
            usedHomeTimbreCorrection: usedHomeTimbreCorrection
        )
    }

    private static func activeVoices(in block: RenderBlock) -> [Voice] {
        var result = EnsembleVoice.allCases.compactMap { voice -> Voice? in
            let count = block.resolvedPerformance.ensemble.events.reduce(0) {
                $0 + ($1.voice == voice ? 1 : 0)
            }
            guard count > 0 else { return nil }
            return Voice(name: InspectorLabel.title(voice.rawValue), eventCount: count)
        }
        let shadowCount = block.synthPerformance.upperNotes.reduce(0) {
            $0 + ($1.role == .shadow ? 1 : 0)
        }
        if shadowCount > 0 {
            result.append(Voice(name: "Shadow", eventCount: shadowCount))
        }
        if block.synthPerformance.composition.padVoicing != nil {
            result.append(Voice(name: "Four-voice pad", eventCount: PadVoicing.voiceCount))
        }
        if let slice = block.synthPerformance.composition.audioSlice {
            result.append(Voice(name: "Audio slice", eventCount: slice.triggers.count))
        }
        if let arpeggiator = block.synthPerformance.composition.arpeggiator {
            result.append(Voice(name: "Arpeggiator", eventCount: arpeggiator.steps.count))
        }
        return result
    }

    private static func activeAssignments(in block: RenderBlock) -> [Assignment] {
        var result: [Assignment] = []
        let bassEventCount = block.resolvedPerformance.ensemble.events.reduce(0) {
            $0 + ($1.voice == .bass ? 1 : 0)
        }
        if bassEventCount > 0 {
            appendAssignment(
                role: "Foundation bass",
                assignment: block.synthPerformance.foundationInstrument,
                eventCount: bassEventCount,
                to: &result
            )
        }
        for role in SynthRole.allCases {
            let notes = block.synthPerformance.upperNotes.filter { $0.role == role }
            for note in notes {
                appendAssignment(
                    role: role == .anchor
                        ? "Motif / anchor"
                        : InspectorLabel.title(role.rawValue),
                    assignment: note.instrument,
                    eventCount: 1,
                    to: &result
                )
            }
        }
        if let pad = block.synthPerformance.composition.padVoicing {
            appendAssignment(
                role: "Four-voice pad",
                assignment: pad.instrument,
                eventCount: pad.voices.count,
                to: &result
            )
        }
        return result
    }

    private static func appendAssignment(
        role: String,
        assignment: InstrumentAssignment,
        eventCount: Int,
        to result: inout [Assignment]
    ) {
        if let index = result.firstIndex(where: {
            $0.role == role &&
                $0.architecture == InspectorLabel.title(assignment.architecture.rawValue) &&
                $0.patch == InspectorLabel.title(assignment.patch.rawValue) &&
                $0.color == assignment.automation.color &&
                $0.shape == assignment.automation.shape &&
                $0.motion == assignment.automation.motion &&
                $0.space == assignment.automation.space &&
                $0.effects == assignment.effects.map {
                    InspectorLabel.title($0.rawValue)
                }
        }) {
            let current = result[index]
            result[index] = Assignment(
                identity: current.identity,
                role: current.role,
                architecture: current.architecture,
                patch: current.patch,
                eventCount: current.eventCount + eventCount,
                color: current.color,
                shape: current.shape,
                motion: current.motion,
                space: current.space,
                effects: current.effects
            )
            return
        }
        let architecture = InspectorLabel.title(assignment.architecture.rawValue)
        let patch = InspectorLabel.title(assignment.patch.rawValue)
        result.append(Assignment(
            identity: "\(role)|\(architecture)|\(patch)|\(result.count)",
            role: role,
            architecture: architecture,
            patch: patch,
            eventCount: eventCount,
            color: assignment.automation.color,
            shape: assignment.automation.shape,
            motion: assignment.automation.motion,
            space: assignment.automation.space,
            effects: assignment.effects.map {
                InspectorLabel.title($0.rawValue)
            }
        ))
    }

    private static func activeCapabilities(in block: RenderBlock) -> [Capability] {
        let composition = block.synthPerformance.composition
        var result: [Capability] = []
        if let slice = composition.audioSlice {
            result.append(Capability(
                name: "Audio slice",
                value: "\(InspectorLabel.title(slice.texture.rawValue)) · \(slice.triggers.count) triggers"
            ))
        }
        if let arpeggiator = composition.arpeggiator {
            result.append(Capability(
                name: "Arpeggiator",
                value: "\(InspectorLabel.title(arpeggiator.direction.rawValue)) · 1/\(arpeggiator.rateInSteps == 1 ? 16 : 8) · \(arpeggiator.steps.count) notes"
            ))
        }
        if let pad = composition.padVoicing {
            result.append(Capability(
                name: "Pad",
                value: "\(InspectorLabel.title(pad.function.rawValue)) · \(InspectorLabel.title(pad.harmonicDisclosureStage.rawValue))"
            ))
            if pad.rhythmicModulation.active {
                result.append(Capability(
                    name: "Pad rhythm",
                    value: InspectorLabel.title(pad.rhythmicModulation.relation.rawValue)
                ))
            }
        }
        if block.synthPerformance.pulseEchoTextureArticulation.driveEligible {
            result.append(Capability(
                name: "Pulse return drive",
                value: String(format: "%.2f", block.synthPerformance
                    .pulseEchoTextureArticulation.appliedAmount)
            ))
        }
        if let texture = block.resolvedPerformance.percussionEchoTexture {
            result.append(Capability(
                name: "Percussion return",
                value: InspectorLabel.title(texture.relation.rawValue)
            ))
        }
        return result
    }
}

package enum InspectorLabel {
    package static func title(_ rawValue: String) -> String {
        let separatorsReplaced = rawValue
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        var expanded = ""
        var previousWasLowercaseOrDigit = false
        for character in separatorsReplaced {
            if character.isUppercase && previousWasLowercaseOrDigit {
                expanded.append(" ")
            }
            expanded.append(character)
            previousWasLowercaseOrDigit = character.isLowercase || character.isNumber
        }
        return expanded.split(separator: " ").map { word in
            let value = String(word)
            if value == value.uppercased(), value.count > 1 { return value }
            return value.prefix(1).uppercased() + value.dropFirst()
        }.joined(separator: " ")
    }
}
