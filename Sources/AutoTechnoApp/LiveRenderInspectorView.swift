import Foundation
import SwiftUI

struct LiveRenderInspectorView: View {
    let snapshot: LiveRenderSnapshot
    let statusTitle: String
    let playingTimeText: String
    let nextPhraseProgress: NextPhraseProgress

    private let intentColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]
    private let metricColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]
    private let visibleAssignmentLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if snapshot.available {
                HStack(alignment: .top, spacing: 10) {
                    musicalStatePanel
                        .frame(width: 168)
                    activeSynthsPanel
                        .frame(maxWidth: .infinity)
                    renderHealthPanel
                        .frame(width: 202)
                }
                .frame(maxHeight: .infinity)
            } else {
                waitingState
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 70)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("CURRENT RENDER")
                .font(.system(size: 19, weight: .black, design: .rounded))
                .tracking(-0.3)
            Text(snapshot.available
                ? "\(statusTitle)  ·  \(playingTimeText)  ·  P\(snapshot.phraseNumber) / B\(snapshot.barNumber)"
                : "\(statusTitle)  ·  WAITING FOR FIRST BAR")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.45)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            nextPhraseBadge
            Text("OFF CALLBACK")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(Color.purple)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.10), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private var nextPhraseBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(nextPhraseProgress.stage == .ready
                    ? Color.green : Color.purple)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(nextPhraseProgress.headline)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.45)
                Text(nextPhraseProgress.detail)
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            (nextPhraseProgress.stage == .ready ? Color.green : Color.purple)
                .opacity(0.10),
            in: Capsule()
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next phrase preparation")
        .accessibilityValue(nextPhraseProgress.accessibilityValue)
        .accessibilityIdentifier("next-phrase-progress")
    }

    private var musicalStatePanel: some View {
        MonitorPanel(title: "Musical state") {
            LazyVGrid(columns: intentColumns, alignment: .leading, spacing: 10) {
                CompactValue(label: "Phrase", value: snapshot.phraseKind)
                CompactValue(label: "Section", value: snapshot.section)
                CompactValue(label: "Character", value: snapshot.performanceCharacter)
                CompactValue(label: "Gesture", value: snapshot.arrangementGesture)
                CompactValue(label: "Foundation", value: snapshot.foundationBehavior)
                CompactValue(label: "Focus", value: snapshot.focusRole)
            }

            MonitorDivider()

            MonitorTextBlock(
                label: "Active voices",
                value: voiceSummary,
                lineLimit: 3
            )

            if !snapshot.capabilities.isEmpty {
                MonitorTextBlock(
                    label: "Live features",
                    value: capabilitySummary,
                    lineLimit: 3
                )
            }

            if let changeSummary {
                MonitorTextBlock(
                    label: "Bar change",
                    value: changeSummary,
                    lineLimit: 2,
                    accent: true
                )
            }
        }
    }

    private var activeSynthsPanel: some View {
        MonitorPanel(title: "Active synths") {
            if snapshot.assignments.isEmpty {
                Text("No synth assignment is active in this bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.assignments.prefix(visibleAssignmentLimit)), id: \.identity) {
                        assignment in
                        CompactAssignmentRow(assignment: assignment)
                        if assignment.identity != visibleAssignments.last?.identity {
                            MonitorDivider()
                        }
                    }
                }
            }

            if hiddenAssignmentCount > 0 {
                Text("+\(hiddenAssignmentCount) more assignment\(hiddenAssignmentCount == 1 ? "" : "s") in this bar")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var renderHealthPanel: some View {
        MonitorPanel(title: "Render health") {
            HStack(spacing: 7) {
                Circle()
                    .fill(snapshot.playbackHardGatesPassed ? Color.green : Color.purple)
                    .frame(width: 6, height: 6)
                Text(snapshot.playbackHardGatesPassed ? "QUALIFIED" : "GATES UNAVAILABLE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.65)
                Spacer(minLength: 4)
                Text(snapshot.qualityOutcome.uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 9) {
                CompactValue(label: "Route", value: routeText)
                CompactValue(label: "Peak", value: amplitudeDB(snapshot.peak, suffix: "dBFS"))
                CompactValue(label: "True peak", value: amplitudeDB(snapshot.truePeak, suffix: "dBTP"))
                CompactValue(label: "RMS", value: amplitudeDB(snapshot.rms, suffix: "dBFS"))
                CompactValue(
                    label: "Correlation",
                    value: String(format: "%.3f", snapshot.stereoCorrelation)
                )
                CompactValue(
                    label: "Master trim",
                    value: String(format: "%+.2f dB", snapshot.liveMasterTrimDB)
                )
            }

            MonitorDivider()

            MonitorTextBlock(
                label: "Engine graph",
                value: "R\(snapshot.graphRevision) · \(snapshot.graphBranchCount) branches · depth \(snapshot.graphMaximumDepth) · \(snapshot.graphNodes.count) nodes",
                lineLimit: 2
            )
            if snapshot.graphMutation != "None" {
                Text(snapshot.graphMutation)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.purple.opacity(0.86))
                    .lineLimit(1)
            }

            MonitorTextBlock(
                label: "Active FX",
                value: effectSummary,
                lineLimit: 3
            )

            MonitorTextBlock(
                label: "Automatic mix",
                value: automaticMixSummary,
                lineLimit: 3,
                accent: true
            )
        }
    }

    private var waitingState: some View {
        VStack(spacing: 13) {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("Preparing the first immutable bar")
                .font(.system(.callout, design: .rounded).weight(.semibold))
            Text("Render information appears after the bar passes automatic qualification.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var visibleAssignments: [LiveRenderSnapshot.Assignment] {
        Array(snapshot.assignments.prefix(visibleAssignmentLimit))
    }

    private var hiddenAssignmentCount: Int {
        max(0, snapshot.assignments.count - visibleAssignmentLimit)
    }

    private var voiceSummary: String {
        guard !snapshot.voices.isEmpty else { return "No scored voices" }
        return snapshot.voices.map { "\($0.name) ×\($0.eventCount)" }.joined(separator: " · ")
    }

    private var capabilitySummary: String {
        snapshot.capabilities.prefix(3).map { "\($0.name): \($0.value)" }
            .joined(separator: " · ")
    }

    private var changeSummary: String? {
        let details = ([snapshot.signatureEvent].compactMap { $0 } + snapshot.transformations)
        guard !details.isEmpty else { return nil }
        return details.prefix(2).joined(separator: " · ")
    }

    private var effectSummary: String {
        guard !snapshot.effects.isEmpty else { return "No active stage" }
        let visible = snapshot.effects.prefix(5).map {
            "\($0.name) \(String(format: "%.2f", $0.amount))"
        }
        let remainder = max(0, snapshot.effects.count - visible.count)
        return visible.joined(separator: " · ") + (remainder > 0 ? " · +\(remainder)" : "")
    }

    private var automaticMixSummary: String {
        let activeGains = snapshot.mixGains.filter { abs($0.decibels) >= 0.005 }
        let gains = (activeGains.isEmpty ? snapshot.mixGains : activeGains).prefix(3).map {
            "\($0.role) \(String(format: "%+.2f", $0.decibels))"
        }
        var parts = gains
        if let measured = snapshot.measuredKickOverFoundationDB,
           let target = snapshot.targetKickOverFoundationDB {
            parts.append(String(format: "K/F %.1f → %.1f dB", measured, target))
        }
        return parts.isEmpty ? "No corrective gain" : parts.joined(separator: " · ")
    }

    private var routeText: String {
        let sampleRate = snapshot.sampleRate / 1_000
        let channelText = snapshot.channelCount == 2 ? "stereo" : "\(snapshot.channelCount) ch"
        return String(format: "%.1f k · %@", sampleRate, channelText)
    }

    private func amplitudeDB(_ amplitude: Double, suffix: String) -> String {
        String(format: "%.1f %@", 20 * log10(max(amplitude, 0.000_000_001)), suffix)
    }
}

private struct MonitorPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .monitorLabelStyle()
            content
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct CompactValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .monitorLabelStyle()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MonitorTextBlock: View {
    let label: String
    let value: String
    let lineLimit: Int
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .monitorLabelStyle()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(accent ? Color.purple : Color.white.opacity(0.76))
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.78)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CompactAssignmentRow: View {
    let assignment: LiveRenderSnapshot.Assignment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(assignment.role)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("×\(assignment.eventCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.purple)
            }
            Text("\(assignment.architecture) · \(assignment.patch)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(spacing: 10) {
                ParameterValue(label: "C", value: assignment.color)
                ParameterValue(label: "S", value: assignment.shape)
                ParameterValue(label: "M", value: assignment.motion)
                ParameterValue(label: "SP", value: assignment.space)
            }
            if !assignment.effects.isEmpty {
                Text(assignment.effects.prefix(3).joined(separator: " · "))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
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
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(Color.white.opacity(0.43))
            Text(String(format: "%.2f", value))
                .foregroundStyle(Color.purple)
                .monospacedDigit()
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
    }
}

private struct MonitorDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }
}

private extension View {
    func monitorLabelStyle() -> some View {
        font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.75)
            .foregroundStyle(Color.white.opacity(0.46))
    }
}
