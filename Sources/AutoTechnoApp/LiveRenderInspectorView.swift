import Foundation
import SwiftUI

struct LiveRenderInspectorView: View {
    let snapshot: LiveRenderSnapshot
    let statusTitle: String
    let playingTimeText: String

    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 210), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if snapshot.available {
                    intentSection
                    voicesSection
                    assignmentsSection
                    capabilitiesSection
                    renderSection
                    graphSection
                    effectsAndMixSection
                    provenanceSection
                } else {
                    waitingState
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 30)
            .padding(.bottom, 82)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .scrollIndicators(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("CURRENT RENDER")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .tracking(-0.5)
                Spacer(minLength: 12)
                Text("PREPARED · OFF CALLBACK")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.10), in: Capsule())
            }
            Text(snapshot.available
                ? "\(statusTitle) · \(playingTimeText) · PHRASE \(snapshot.phraseNumber) · BAR \(snapshot.barNumber)"
                : "\(statusTitle) · WAITING FOR THE FIRST IMMUTABLE BAR")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Text("Values change only when an already-scheduled bar becomes current.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .accessibilityElement(children: .combine)
    }

    private var intentSection: some View {
        InspectorSection(title: "Musical intent") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                InspectorValue(label: "Phrase", value: snapshot.phraseKind)
                InspectorValue(label: "Section", value: snapshot.section)
                InspectorValue(label: "Character", value: snapshot.performanceCharacter)
                InspectorValue(label: "Gesture", value: snapshot.arrangementGesture)
                InspectorValue(label: "Interlock", value: snapshot.interlockChapter)
                InspectorValue(label: "Foundation", value: snapshot.foundationBehavior)
                InspectorValue(label: "Foreground", value: snapshot.focusRole)
                InspectorValue(label: "Kick syntax", value: snapshot.kickSyntax)
                InspectorValue(label: "Percussion", value: snapshot.percussionGear)
                if let signature = snapshot.signatureEvent {
                    InspectorValue(label: "Signature", value: signature)
                }
                if !snapshot.transformations.isEmpty {
                    InspectorValue(
                        label: "Transformations",
                        value: snapshot.transformations.joined(separator: " · ")
                    )
                }
            }
        }
    }

    private var voicesSection: some View {
        InspectorSection(title: "Active score voices") {
            FlowLayout(spacing: 8) {
                ForEach(Array(snapshot.voices.enumerated()), id: \.offset) { _, voice in
                    HStack(spacing: 6) {
                        Text(voice.name)
                        Text("×\(voice.eventCount)")
                            .foregroundStyle(Color.orange)
                    }
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.055), in: Capsule())
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var assignmentsSection: some View {
        InspectorSection(title: "Synth assignments") {
            if snapshot.assignments.isEmpty {
                InspectorEmptyRow(text: "No synth assignment is active in this bar.")
            } else {
                VStack(spacing: 0) {
                    ForEach(snapshot.assignments, id: \.identity) { assignment in
                        AssignmentRow(assignment: assignment)
                        if assignment.identity != snapshot.assignments.last?.identity {
                            Divider().overlay(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var capabilitiesSection: some View {
        if !snapshot.capabilities.isEmpty {
            InspectorSection(title: "Bar capabilities") {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(Array(snapshot.capabilities.enumerated()), id: \.offset) { _, item in
                        InspectorValue(label: item.name, value: item.value)
                    }
                }
            }
        }
    }

    private var renderSection: some View {
        InspectorSection(title: "Rendered buffer") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                InspectorValue(label: "Route", value: routeText)
                InspectorValue(label: "Frames", value: snapshot.frameCount.formatted())
                InspectorValue(
                    label: "Duration",
                    value: String(format: "%.3f s", snapshot.durationSeconds)
                )
                InspectorValue(label: "Peak", value: amplitudeDB(snapshot.peak, suffix: "dBFS"))
                InspectorValue(label: "True peak", value: amplitudeDB(snapshot.truePeak, suffix: "dBTP"))
                InspectorValue(label: "RMS", value: amplitudeDB(snapshot.rms, suffix: "dBFS"))
                InspectorValue(
                    label: "Loudness estimate",
                    value: String(format: "%.1f dB", snapshot.loudnessEstimate)
                )
                InspectorValue(
                    label: "Stereo correlation",
                    value: String(format: "%.3f", snapshot.stereoCorrelation)
                )
                InspectorValue(
                    label: "Live master trim",
                    value: String(format: "%+.2f dB", snapshot.liveMasterTrimDB)
                )
                InspectorValue(
                    label: "Hard gates",
                    value: snapshot.playbackHardGatesPassed ? "Passed" : "Unavailable"
                )
            }
        }
    }

    private var graphSection: some View {
        InspectorSection(title: "Generated upper graph") {
            HStack(spacing: 18) {
                InspectorInlineValue(label: "REV", value: "\(snapshot.graphRevision)")
                InspectorInlineValue(label: "BRANCHES", value: "\(snapshot.graphBranchCount)")
                InspectorInlineValue(label: "DEPTH", value: "\(snapshot.graphMaximumDepth)")
                InspectorInlineValue(label: "MUTATION", value: snapshot.graphMutation)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                ForEach(snapshot.graphNodes, id: \.identity) { node in
                    GraphNodeRow(node: node)
                    if node.identity != snapshot.graphNodes.last?.identity {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }

    private var effectsAndMixSection: some View {
        InspectorSection(title: "Effects and automatic mix") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 28) {
                    effectsList.frame(maxWidth: .infinity, alignment: .leading)
                    mixList.frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 18) {
                    effectsList
                    mixList
                }
            }
        }
    }

    private var effectsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVE STAGES")
                .inspectorLabelStyle()
            ForEach(Array(snapshot.effects.enumerated()), id: \.offset) { _, effect in
                HStack {
                    Text(effect.name)
                    Spacer(minLength: 10)
                    Text(String(format: "%.2f", effect.amount))
                        .foregroundStyle(Color.orange)
                        .monospacedDigit()
                }
                .font(.system(.caption, design: .monospaced))
            }
            if snapshot.effects.isEmpty {
                Text("No active stage reported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mixList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROLE FADERS")
                .inspectorLabelStyle()
            ForEach(Array(snapshot.mixGains.enumerated()), id: \.offset) { _, gain in
                HStack {
                    Text(gain.role)
                    Spacer(minLength: 10)
                    Text(String(format: "%+.2f dB", gain.decibels))
                        .foregroundStyle(Color.orange)
                        .monospacedDigit()
                }
                .font(.system(.caption, design: .monospaced))
            }
            if let measured = snapshot.measuredKickOverFoundationDB,
               let target = snapshot.targetKickOverFoundationDB {
                Text(String(
                    format: "Kick / foundation %.2f dB · target %.2f dB",
                    measured,
                    target
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var provenanceSection: some View {
        InspectorSection(title: "Preparation verdict") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                InspectorValue(label: "Outcome", value: snapshot.qualityOutcome)
                InspectorValue(
                    label: "Home correction",
                    value: snapshot.usedHomeTimbreCorrection ? "Applied" : "Not used"
                )
                InspectorValue(label: "Policy", value: snapshot.qualityPolicyVersion)
            }
        }
    }

    private var waitingState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Render information appears when preparation accepts the first bar.")
                .font(.callout)
                .foregroundStyle(Color.white.opacity(0.70))
        }
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }

    private var routeText: String {
        let sampleRate = snapshot.sampleRate / 1_000
        let channelText = snapshot.channelCount == 2 ? "stereo" : "\(snapshot.channelCount) ch"
        return String(format: "%.1f kHz · %@", sampleRate, channelText)
    }

    private func amplitudeDB(_ amplitude: Double, suffix: String) -> String {
        String(format: "%.1f %@", 20 * log10(max(amplitude, 0.000_000_001)), suffix)
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.55))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct InspectorValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .inspectorLabelStyle()
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct InspectorInlineValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).inspectorLabelStyle()
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AssignmentRow: View {
    let assignment: LiveRenderSnapshot.Assignment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(assignment.role)
                        .font(.system(.body, design: .rounded).weight(.bold))
                    Text("\(assignment.architecture) · \(assignment.patch) · \(assignment.eventCount) events")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(assignment.effects.joined(separator: " · "))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .multilineTextAlignment(.trailing)
            }
            HStack(spacing: 18) {
                ParameterValue(label: "C", value: assignment.color)
                ParameterValue(label: "S", value: assignment.shape)
                ParameterValue(label: "M", value: assignment.motion)
                ParameterValue(label: "SPACE", value: assignment.space)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(assignment.role), \(assignment.architecture), \(assignment.patch), " +
            "color \(assignment.color), shape \(assignment.shape), " +
            "motion \(assignment.motion), space \(assignment.space)"
        )
    }
}

private struct ParameterValue: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .foregroundStyle(Color.white.opacity(0.48))
            Text(String(format: "%.2f", value))
                .foregroundStyle(Color.orange)
                .monospacedDigit()
        }
        .font(.system(.caption, design: .monospaced).weight(.semibold))
    }
}

private struct GraphNodeRow: View {
    let node: LiveRenderSnapshot.GraphNode

    var body: some View {
        HStack(spacing: 12) {
            Text("B\(node.branch)")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.orange)
                .frame(width: 24, alignment: .leading)
            Text(node.name)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .frame(minWidth: 82, maxWidth: .infinity, alignment: .leading)
            Text(String(format: "A %.2f", node.amount))
            Text(String(format: "M %.2f", node.mix))
            if node.feedback > 0 {
                Text(String(format: "F %.2f", node.feedback))
            }
            if node.delayMilliseconds > 0 {
                Text(String(format: "%.0f ms", node.delayMilliseconds))
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.72))
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct InspectorEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
}

private extension View {
    func inspectorLabelStyle() -> some View {
        font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Color.white.opacity(0.46))
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (
            CGSize(width: proposal.width ?? max(0, x - spacing), height: y + lineHeight),
            points
        )
    }
}
