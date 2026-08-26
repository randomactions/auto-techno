import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var engine = TechnoEngine()
    @State private var selectedView: AppView = .performance

    private enum AppView: Equatable {
        case performance
        case renderInspector
    }

    var body: some View {
        ZStack {
            Color(red: 0.018, green: 0.020, blue: 0.026)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.orange.opacity(engine.isPlaying ? 0.10 : 0.035), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.8), value: engine.isPlaying)

            Group {
                switch selectedView {
                case .performance:
                    performanceView
                case .renderInspector:
                    LiveRenderInspectorView(
                        snapshot: engine.liveRenderSnapshot,
                        statusTitle: engine.statusTitle,
                        playingTimeText: engine.playingTimeText,
                        nextPhraseProgress: engine.nextPhraseProgress
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                selectedView = selectedView == .performance
                    ? .renderInspector : .performance
            } label: {
                Label(
                    selectedView == .performance ? "RENDER INFO" : "PERFORMANCE",
                    systemImage: selectedView == .performance
                        ? "waveform.path.ecg" : "play.rectangle"
                )
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .tracking(1.0)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(selectedView == .renderInspector
                            ? Color.orange.opacity(0.12)
                            : Color.clear)
                        .overlay {
                            Capsule()
                                .stroke(
                                    selectedView == .renderInspector
                                        ? Color.orange.opacity(0.55)
                                        : Color.white.opacity(0.22),
                                    lineWidth: 1
                                )
                        }
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("i", modifiers: [.command])
            .accessibilityLabel(
                selectedView == .performance
                    ? "Show live render information"
                    : "Show performance controls"
            )
            .accessibilityHint(
                "Switches between the transport and read-only current render details"
            )
            .accessibilityIdentifier("view-render-inspector")
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            Button {
                engine.startNewSet()
            } label: {
                Label("NEW SET", systemImage: "arrow.counterclockwise")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .tracking(1.2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!engine.newSetEnabled)
            .opacity(engine.newSetEnabled ? 1 : 0.42)
            .keyboardShortcut("n", modifiers: [.command])
            .accessibilityLabel("Start a new set")
            .accessibilityHint("Ends the current set and starts a fresh performance")
            .accessibilityIdentifier("transport-new-set")
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(minWidth: 680, minHeight: 480)
        .preferredColorScheme(.dark)
        .onAppear { engine.prepare() }
        .onDisappear { engine.shutdown() }
    }

    private var performanceView: some View {
        VStack(spacing: 34) {
            VStack(spacing: 7) {
                Text("AUTO TECHNO")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .tracking(-0.8)
                Text(engine.statusTitle)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .tracking(1.7)
                    .foregroundStyle(engine.isPlaying ? Color.orange : Color.secondary)
            }

            PerformanceWaveform(
                samples: engine.waveform,
                playhead: engine.playhead,
                active: engine.isPlaying
            )
            .frame(height: 118)
            .accessibilityHidden(true)

            Button {
                engine.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(engine.isPlaying ? Color.orange : Color.white)
                        .frame(width: 94, height: 94)
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .offset(x: engine.isPlaying ? 0 : 2)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!engine.transportEnabled)
            .opacity(engine.transportEnabled ? 1 : 0.42)
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(engine.transportTitle)
            .accessibilityIdentifier("transport-play-pause")

            VStack(spacing: 7) {
                Text(engine.playingTimeText)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(engine.isPlaying ? Color.white : Color.secondary)
                    .accessibilityLabel("Playing time")
                    .accessibilityValue(engine.playingTimeText)
                    .accessibilityIdentifier("playing-time")

                Text(engine.positionText)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(42)
        .frame(maxWidth: 680)
    }
}

private struct PerformanceWaveform: View {
    let samples: [Float]
    let playhead: Double
    let active: Bool

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty, size.width > 0, size.height > 0 else { return }
            let spacing = size.width / CGFloat(samples.count)
            let center = size.height * 0.5
            let progressX = size.width * CGFloat(min(1, max(0, playhead)))

            for (index, sample) in samples.enumerated() {
                let x = (CGFloat(index) + 0.5) * spacing
                let normalized = CGFloat(min(1, max(0.04, sample)))
                let halfHeight = max(2, normalized * center * 0.86)
                let rect = CGRect(
                    x: x - max(1, spacing * 0.18),
                    y: center - halfHeight,
                    width: max(2, spacing * 0.36),
                    height: halfHeight * 2
                )
                let played = x <= progressX
                let color = played && active
                    ? Color.orange.opacity(0.88)
                    : Color.white.opacity(active ? 0.24 : 0.13)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: rect.width * 0.5),
                    with: .color(color)
                )
            }
        }
        .animation(.easeOut(duration: 0.18), value: samples)
    }
}
