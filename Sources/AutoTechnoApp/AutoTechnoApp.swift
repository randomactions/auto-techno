import AppKit
import SwiftUI

@main
struct AutoTechnoApp: App {
    var body: some Scene {
        WindowGroup("Auto Techno") {
            ContentView()
                .background(WindowConfigurator())
        }
        .windowResizability(.automatic)
        .defaultSize(width: 640, height: 480)
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowObservingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(nsView.window)
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 480, height: 390)
    }
}

private final class WindowObservingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 480, height: 390)
        window.contentMinSize = NSSize(width: 480, height: 390)
    }
}
