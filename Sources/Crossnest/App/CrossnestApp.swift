import AppKit
import Combine
import SwiftUI

/// Shows a Dock icon only while the main window is open. With the window closed and a live feature
/// on, Crossnest lives in the menu bar alone; with nothing on, it quits.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the window's content, because only a view can reach SwiftUI's openWindow action.
    static var openMainWindow: (() -> Void)?
    private var featuresObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hasLiveFeatures = MainActor.assumeIsolated { !LiveFeatures.shared.enabled.isEmpty }
        if Self.launchedAsLoginItem && hasLiveFeatures {
            // Started at login: stay out of the way, menu bar only.
            DispatchQueue.main.async {
                Self.mainWindows.forEach { $0.close() }
                NSApp.setActivationPolicy(.accessory)
            }
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose),
                                               name: NSWindow.willCloseNotification, object: nil)
        // If the last live feature is switched off from the menu bar, the icon disappears too,
        // so bring the window back rather than leaving an invisible app running.
        featuresObserver = MainActor.assumeIsolated {
            LiveFeatures.shared.$enabled.dropFirst().sink { enabled in
                if enabled.isEmpty, Self.mainWindows.isEmpty { Self.showMainWindow() }
            }
        }
    }

    /// Clicking the Dock icon or opening the app again while it's running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { Self.showMainWindow() }
        return true
    }

    /// Keep running in the menu bar while a live feature (Alt+Tab etc.) is on; otherwise quit with the window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MainActor.assumeIsolated { LiveFeatures.shared.enabled.isEmpty }
    }

    static func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openMainWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func windowWillClose(_ note: Notification) {
        guard let closing = note.object as? NSWindow, Self.isMainWindow(closing) else { return }
        // The closing window is still listed; check again once it has gone.
        DispatchQueue.main.async {
            guard Self.mainWindows.isEmpty else { return }
            let hasLiveFeatures = MainActor.assumeIsolated { !LiveFeatures.shared.enabled.isEmpty }
            if hasLiveFeatures { NSApp.setActivationPolicy(.accessory) }
        }
    }

    private static var mainWindows: [NSWindow] {
        NSApp.windows.filter { isMainWindow($0) && $0.isVisible }
    }

    private static func isMainWindow(_ window: NSWindow) -> Bool {
        !(window is NSPanel) && window.level == .normal && window.styleMask.contains(.titled)
    }

    /// macOS marks the launch Apple event when the app was started as a login item.
    private static var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication else { return false }
        let keyAELaunchedAsLogInItem: FourCharCode = 0x6C67_6974  // 'lgit'
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}

/// Hands the openWindow action to the app delegate so it can reopen the window from the Dock or menu bar.
private struct WindowOpenerRegistrar: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    func body(content: Content) -> some View {
        content.onAppear { AppDelegate.openMainWindow = { openWindow(id: "main") } }
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
                .modifier(WindowOpenerRegistrar())
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
            MenuBarIcon(mouseLock: live.mouseLock)
        }
    }
}

/// Grey template icon normally; blue while Mouse Lock is holding the pointer.
private struct MenuBarIcon: View {
    @ObservedObject var mouseLock: MouseLock

    var body: some View {
        Image(nsImage: mouseLock.isLocking ? Self.lockedIcon : Self.normalIcon)
    }

    private static let normalIcon: NSImage = {
        let image = NSImage(systemSymbolName: "arrow.uturn.down.square", accessibilityDescription: "Crossnest")!
        image.isTemplate = true
        return image
    }()

    private static let lockedIcon: NSImage = {
        let config = NSImage.SymbolConfiguration(paletteColors: [.systemBlue])
        let image = NSImage(systemSymbolName: "arrow.uturn.down.square", accessibilityDescription: "Crossnest: Mouse Lock active")!
            .withSymbolConfiguration(config)!
        image.isTemplate = false  // keep the colour instead of the menu bar's grey
        return image
    }()
}

private struct MenuBarMenu: View {
    @EnvironmentObject private var engine: TweakEngine
    @EnvironmentObject private var live: LiveFeatures

    var body: some View {
        Button("Open Crossnest") { AppDelegate.showMainWindow() }
        if !live.hasPermission {
            Button("Grant Accessibility Permission…") { live.openAccessibilitySettings() }
        }
        Divider()
        ForEach(engine.tweaks.filter(\.isLive)) { tweak in
            Toggle(tweak.title, isOn: Binding(get: { engine.isOn(tweak) },
                                              set: { engine.set(tweak, on: $0) }))
        }
        Toggle("Mouse Lock", isOn: Binding(get: { live.isOn(.mouseLock) },
                                           set: { live.set(.mouseLock, on: $0) }))
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
