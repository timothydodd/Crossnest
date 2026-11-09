import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched via `swift run` (no .app bundle).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    /// Keep running in the menu bar while a live feature (Alt+Tab etc.) is on; otherwise quit with the window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MainActor.assumeIsolated { LiveFeatures.shared.enabled.isEmpty }
    }
}

@main
struct CrossnestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var engine = TweakEngine()
    @StateObject private var live = LiveFeatures.shared

    var body: some Scene {
        Window("Crossnest", id: "main") {
            ContentView()
                .environmentObject(engine)
                .environmentObject(live)
                .frame(minWidth: 820, minHeight: 560)
                .tint(Theme.accent)
        }
        .defaultSize(width: 1040, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra(isInserted: Binding(get: { !live.enabled.isEmpty }, set: { _ in })) {
            MenuBarMenu()
                .environmentObject(engine)
                .environmentObject(live)
        } label: {
            Image(systemName: "arrow.uturn.down.square")
        }
    }
}

private struct MenuBarMenu: View {
    @EnvironmentObject private var engine: TweakEngine
    @EnvironmentObject private var live: LiveFeatures
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Crossnest") {
            openWindow(id: "main")
            NSApp.activate()
        }
        if !live.hasPermission {
            Button("Grant Accessibility Permission…") { live.openAccessibilitySettings() }
        }
        Divider()
        ForEach(engine.tweaks.filter(\.isLive)) { tweak in
            Toggle(tweak.title, isOn: Binding(get: { engine.isOn(tweak) },
                                              set: { engine.set(tweak, on: $0) }))
        }
        Divider()
        Toggle("Open at Login", isOn: Binding(get: { live.opensAtLogin },
                                              set: { live.setOpensAtLogin($0) }))
        Button("Quit Crossnest") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

extension Tweak {
    var isLive: Bool {
        if case .live = kind { return true }
        return false
    }
}
