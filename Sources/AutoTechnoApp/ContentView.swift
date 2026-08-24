import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var engine = TechnoEngine()

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
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(minWidth: 480, minHeight: 390)
        .preferredColorScheme(.dark)
        .onAppear { engine.prepare() }
        .onDisappear { engine.shutdown() }
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
