import Foundation
import Testing
@testable import AutoTechnoApp

@Suite("Monitoring-only output control")
struct MonitoringOutputTests {
    @Test("Mute preserves the selected level and zero restores the last audible level")
    func stateTransitionsAreBounded() {
        var state = MonitoringOutputState()
        #expect(state.volume == 1)
        #expect(!state.isMuted)
        #expect(state.linearGain == 1)

        state.setVolume(0.32)
        #expect(state.volume == 0.32)
        #expect(!state.isMuted)
        #expect(state.linearGain == Float(0.32))

        state.toggleMute()
        #expect(state.isMuted)
        #expect(state.volume == 0.32)
        #expect(state.linearGain == 0)

        state.toggleMute()
        #expect(!state.isMuted)
        #expect(state.volume == 0.32)

        state.setVolume(0)
        #expect(state.isMuted)
        #expect(state.volume == 0)
        state.toggleMute()
        #expect(!state.isMuted)
        #expect(state.volume == 0.32)
    }

    @Test("Volume clamps finite input and rejects non-finite input")
    func inputIsBounded() {
        var state = MonitoringOutputState()
        state.setVolume(4)
        #expect(state.volume == 1)
        state.setVolume(-2)
        #expect(state.volume == 0)
        state.setVolume(0.41)
        state.setVolume(.infinity)
        #expect(state.volume == 0.41)
        #expect(!state.isMuted)
    }

    @MainActor
    @Test("Engine exposes the monitoring state without changing session identity")
    func engineStateIsHostLocal() {
        let engine = TechnoEngine(
            sessionSeedSource: AutonomousSessionSeedSource { 42 }
        )
        let seed = engine.currentSessionSeed

        engine.setMonitoringVolume(0.18)
        #expect(engine.monitoringOutput.volume == 0.18)
        #expect(engine.monitoringOutput.linearGain == Float(0.18))
        #expect(engine.currentSessionSeed == seed)

        engine.toggleMonitoringMute()
        #expect(engine.monitoringOutput.isMuted)
        #expect(engine.monitoringOutput.linearGain == 0)
        #expect(engine.currentSessionSeed == seed)
        engine.shutdown()
    }

    @Test("UI and graph keep monitoring gain downstream of canonical capture")
    func topologyAndAccessibilityAreExplicit() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let engine = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AutoTechnoApp/TechnoEngine.swift"
            ),
            encoding: .utf8
        )
        let view = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/AutoTechnoApp/ContentView.swift"
            ),
            encoding: .utf8
        )

        #expect(engine.contains(
            "audioEngine.connect(player, to: canonicalCaptureMixer"
        ))
        #expect(engine.contains(
            "canonicalCaptureMixer,\n            to: audioEngine.mainMixerNode"
        ))
        #expect(engine.contains("on: self.canonicalCaptureMixer"))
        #expect(engine.contains(
            "audioEngine.mainMixerNode.outputVolume = " +
                "monitoringOutput.linearGain"
        ))
        #expect(!engine.contains(
            "transport.installTap(\n                    on: " +
                "self.audioEngine.mainMixerNode"
        ))
        #expect(view.contains("monitoring-mute"))
        #expect(view.contains("monitoring-volume"))
        #expect(view.contains("private var bottomControlBar: some View"))
        #expect(view.contains("Spacer(minLength: 160)"))
        #expect(view.contains(".padding(.bottom, 22)"))
        #expect(view.contains(".padding(.bottom, 28)"))
        #expect(!view.contains("Text(engine.positionText)"))
        #expect(view.contains(
            "keyboardShortcut(\"m\", modifiers: [.command])"
        ))
    }
}
